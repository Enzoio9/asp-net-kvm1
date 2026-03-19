#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ollama Web API - Production Backend
FastAPI-based backend with multi-threading, SQLite, and WebSocket support
"""

import os
import sys
import json
import time
import uuid
import sqlite3
import threading
import queue
import asyncio
import hashlib
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from contextlib import contextmanager

from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect, UploadFile, File, BackgroundTasks, Depends, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import uvicorn

# ============================================================
# CONFIGURAÇÕES GLOBAIS
# ============================================================

BASE_DIR = Path(__file__).parent.parent
VIDEO_DIR = Path(os.getenv("VIDEO_DIR", "/root/videos"))
IMAGE_DIR = Path(os.getenv("IMAGE_DIR", "/root/images"))
DB_PATH = Path(os.getenv("DB_PATH", "/root/ollama-web/backend/queue.db"))
LOG_PATH = Path(os.getenv("LOG_PATH", "/root/ollama-web/backend/app.log"))
METRICS_PATH = Path(os.getenv("METRICS_PATH", "/root/ollama-web/backend/metrics.json"))

# Configurações da API
API_PREFIX = os.getenv("API_PREFIX", "/api/v1")
MAX_CONCURRENT_JOBS = int(os.getenv("MAX_CONCURRENT_JOBS", "3"))
MAX_QUEUE_SIZE = int(os.getenv("MAX_QUEUE_SIZE", "100"))
RATE_LIMIT_PER_MINUTE = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))

# Segurança
API_KEY = os.getenv("API_KEY", "ollama-web-secret-key-change-in-production")
ENABLE_AUTH = os.getenv("ENABLE_AUTH", "false").lower() == "true"

# Ollama
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "runway/gen2-lite")

# ============================================================
# MODELOS DE DADOS
# ============================================================

@dataclass
class VideoJob:
    id: str
    prompt: str
    image_path: Optional[str]
    video_path: Optional[str]
    status: str
    progress: int
    created_at: str
    updated_at: str
    error_message: Optional[str]
    metadata: Dict[str, Any]

class JobCreate(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=2000)
    image_url: Optional[str] = None
    duration: int = Field(default=5, ge=1, le=60)
    resolution: str = Field(default="720p", pattern="^(480p|720p|1080p)$")
    style: Optional[str] = None

class JobUpdate(BaseModel):
    status: Optional[str] = None
    progress: Optional[int] = Field(default=None, ge=0, le=100)
    error_message: Optional[str] = None

class JobResponse(BaseModel):
    id: str
    status: str
    progress: int
    prompt: str
    video_url: Optional[str]
    thumbnail_url: Optional[str]
    created_at: str
    updated_at: str
    error_message: Optional[str]

# ============================================================
# GERENCIADOR DE BANCO DE DADOS
# ============================================================

class DatabaseManager:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.local = threading.local()
        self._init_db()
    
    def _get_connection(self) -> sqlite3.Connection:
        if not hasattr(self.local, 'connection') or self.local.connection is None:
            self.local.connection = sqlite3.connect(str(self.db_path), check_same_thread=False)
            self.local.connection.row_factory = sqlite3.Row
        return self.local.connection
    
    def _init_db(self):
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS jobs (
                id TEXT PRIMARY KEY,
                prompt TEXT NOT NULL,
                image_path TEXT,
                video_path TEXT,
                status TEXT NOT NULL DEFAULT 'pending',
                progress INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                error_message TEXT,
                metadata TEXT
            )
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status)
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                metric_name TEXT NOT NULL,
                metric_value REAL NOT NULL,
                metadata TEXT
            )
        ''')
        
        conn.commit()
    
    @contextmanager
    def transaction(self):
        conn = self._get_connection()
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
    
    def create_job(self, job: VideoJob) -> VideoJob:
        with self.transaction():
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO jobs (id, prompt, image_path, video_path, status, progress, 
                                 created_at, updated_at, error_message, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (job.id, job.prompt, job.image_path, job.video_path, job.status,
                  job.progress, job.created_at, job.updated_at, job.error_message,
                  json.dumps(job.metadata)))
        return job
    
    def get_job(self, job_id: str) -> Optional[VideoJob]:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM jobs WHERE id = ?', (job_id,))
        row = cursor.fetchone()
        
        if row:
            return VideoJob(
                id=row['id'], prompt=row['prompt'], image_path=row['image_path'],
                video_path=row['video_path'], status=row['status'], progress=row['progress'],
                created_at=row['created_at'], updated_at=row['updated_at'],
                error_message=row['error_message'], metadata=json.loads(row['metadata'])
            )
        return None
    
    def update_job(self, job_id: str, **kwargs) -> Optional[VideoJob]:
        job = self.get_job(job_id)
        if not job:
            return None
        
        for key, value in kwargs.items():
            if hasattr(job, key):
                setattr(job, key, value)
        
        job.updated_at = datetime.utcnow().isoformat()
        
        with self.transaction():
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE jobs SET prompt=?, image_path=?, video_path=?, status=?,
                               progress=?, updated_at=?, error_message=?, metadata=?
                WHERE id=?
            ''', (job.prompt, job.image_path, job.video_path, job.status,
                  job.progress, job.updated_at, job.error_message,
                  json.dumps(job.metadata), job.id))
        
        return job
    
    def list_jobs(self, status: Optional[str] = None, limit: int = 50, offset: int = 0) -> List[VideoJob]:
        conn = self._get_connection()
        cursor = conn.cursor()
        
        if status:
            cursor.execute('SELECT * FROM jobs WHERE status = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
                          (status, limit, offset))
        else:
            cursor.execute('SELECT * FROM jobs ORDER BY created_at DESC LIMIT ? OFFSET ?',
                          (limit, offset))
        
        return [
            VideoJob(
                id=row['id'], prompt=row['prompt'], image_path=row['image_path'],
                video_path=row['video_path'], status=row['status'], progress=row['progress'],
                created_at=row['created_at'], updated_at=row['updated_at'],
                error_message=row['error_message'], metadata=json.loads(row['metadata'])
            )
            for row in cursor.fetchall()
        ]
    
    def delete_job(self, job_id: str) -> bool:
        with self.transaction():
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute('DELETE FROM jobs WHERE id = ?', (job_id,))
            return cursor.rowcount > 0

# ============================================================
# GERENCIADOR DE FILA E PROCESSAMENTO
# ============================================================

class JobQueueManager:
    def __init__(self, db: DatabaseManager, max_workers: int = 3):
        self.db = db
        self.max_workers = max_workers
        self.job_queue = queue.Queue(maxsize=MAX_QUEUE_SIZE)
        self.active_jobs: Dict[str, threading.Thread] = {}
        self.workers = []
        self.running = True
        
    def start_workers(self):
        """Inicia workers para processar jobs em paralelo"""
        for i in range(self.max_workers):
            worker = threading.Thread(target=self._worker_loop, args=(i,), daemon=True)
            worker.start()
            self.workers.append(worker)
        print(f"✅ {self.max_workers} workers iniciados")
    
    def _worker_loop(self, worker_id: int):
        """Loop principal do worker"""
        print(f"Worker {worker_id} iniciado")
        while self.running:
            try:
                job_id = self.job_queue.get(timeout=1)
                self._process_job(job_id, worker_id)
                self.job_queue.task_done()
            except queue.Empty:
                continue
            except Exception as e:
                print(f"❌ Worker {worker_id} error: {e}")
    
    def _process_job(self, job_id: str, worker_id: int):
        """Processa um job individual"""
        job = self.db.get_job(job_id)
        if not job:
            return
        
        try:
            # Atualiza status para processando
            self.db.update_job(job_id, status="processing", progress=10)
            
            # Simula processamento (substituir por chamada real ao Ollama)
            for progress in range(10, 100, 10):
                time.sleep(1)  # Simula trabalho
                self.db.update_job(job_id, progress=progress)
                
                # Verifica se deve cancelar
                current_job = self.db.get_job(job_id)
                if current_job and current_job.status == "cancelled":
                    return
            
            # Finaliza job
            video_path = f"/videos/{job_id}.mp4"
            self.db.update_job(job_id, status="completed", progress=100, video_path=video_path)
            print(f"✅ Job {job_id} completado pelo worker {worker_id}")
            
        except Exception as e:
            self.db.update_job(job_id, status="failed", error_message=str(e))
            print(f"❌ Job {job_id} falhou: {e}")
    
    def add_job(self, job_id: str):
        """Adiciona job à fila"""
        try:
            self.job_queue.put(job_id, block=False)
            return True
        except queue.Full:
            return False
    
    def cancel_job(self, job_id: str):
        """Cancela um job"""
        job = self.db.get_job(job_id)
        if job and job.status == "pending":
            self.db.update_job(job_id, status="cancelled")
            return True
        elif job and job.status == "processing":
            # Marca para cancelamento
            self.db.update_job(job_id, status="cancelling")
            return True
        return False

# ============================================================
# APLICAÇÃO FASTAPI
# ============================================================

def create_app() -> FastAPI:
    app = FastAPI(
        title="Ollama Web API",
        description="API para geração de vídeos com IA usando Ollama",
        version="1.0.0"
    )
    
    # Middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Inicializa componentes
    db = DatabaseManager(DB_PATH)
    queue_manager = JobQueueManager(db, MAX_CONCURRENT_JOBS)
    
    # Segurança
    security = HTTPBearer(auto_error=False)
    
    async def verify_auth(credentials: HTTPAuthorizationCredentials = Security(security)):
        if not ENABLE_AUTH:
            return None
        if credentials is None:
            raise HTTPException(status_code=401, detail="Missing authentication token")
        if credentials.credentials != API_KEY:
            raise HTTPException(status_code=401, detail="Invalid authentication token")
        return credentials.credentials
    
    # Endpoints
    @app.get("/")
    async def root():
        return {
            "message": "Ollama Web API",
            "version": "1.0.0",
            "docs": "/docs",
            "health": "/health"
        }
    
    @app.get("/health")
    async def health_check():
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "queue_size": queue_manager.job_queue.qsize(),
            "active_workers": len(queue_manager.workers)
        }
    
    @app.post(f"{API_PREFIX}/jobs", response_model=JobResponse)
    async def create_job(
        job_data: JobCreate,
        background_tasks: BackgroundTasks,
        auth=Depends(verify_auth)
    ):
        job_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        
        job = VideoJob(
            id=job_id,
            prompt=job_data.prompt,
            image_path=None,
            video_path=None,
            status="pending",
            progress=0,
            created_at=now,
            updated_at=now,
            error_message=None,
            metadata={
                "duration": job_data.duration,
                "resolution": job_data.resolution,
                "style": job_data.style
            }
        )
        
        db.create_job(job)
        
        if not queue_manager.add_job(job_id):
            raise HTTPException(status_code=503, detail="Queue is full")
        
        return JobResponse(
            id=job.id,
            status=job.status,
            progress=job.progress,
            prompt=job.prompt,
            video_url=None,
            thumbnail_url=None,
            created_at=job.created_at,
            updated_at=job.updated_at,
            error_message=job.error_message
        )
    
    @app.get(f"{API_PREFIX}/jobs", response_model=List[JobResponse])
    async def list_jobs(
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
        auth=Depends(verify_auth)
    ):
        jobs = db.list_jobs(status=status, limit=limit, offset=offset)
        return [
            JobResponse(
                id=job.id,
                status=job.status,
                progress=job.progress,
                prompt=job.prompt,
                video_url=f"/videos/{job.video_path}" if job.video_path else None,
                thumbnail_url=None,
                created_at=job.created_at,
                updated_at=job.updated_at,
                error_message=job.error_message
            )
            for job in jobs
        ]
    
    @app.get(f"{API_PREFIX}/jobs/{{job_id}}", response_model=JobResponse)
    async def get_job(job_id: str, auth=Depends(verify_auth)):
        job = db.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        return JobResponse(
            id=job.id,
            status=job.status,
            progress=job.progress,
            prompt=job.prompt,
            video_url=f"/videos/{job.video_path}" if job.video_path else None,
            thumbnail_url=None,
            created_at=job.created_at,
            updated_at=job.updated_at,
            error_message=job.error_message
        )
    
    @app.delete(f"{API_PREFIX}/jobs/{{job_id}}")
    async def delete_job(job_id: str, auth=Depends(verify_auth)):
        if not db.delete_job(job_id):
            raise HTTPException(status_code=404, detail="Job not found")
        return {"message": "Job deleted successfully"}
    
    @app.post(f"{API_PREFIX}/jobs/{{job_id}}/cancel")
    async def cancel_job(job_id: str, auth=Depends(verify_auth)):
        job = db.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if queue_manager.cancel_job(job_id):
            return {"message": "Job cancellation requested"}
        else:
            raise HTTPException(status_code=400, detail="Cannot cancel job in current state")
    
    @app.websocket("/ws/jobs")
    async def websocket_endpoint(websocket: WebSocket):
        await websocket.accept()
        
        try:
            while True:
                # Envia status de todos os jobs ativos
                active_jobs = db.list_jobs(status="processing")
                await websocket.send_json({
                    "type": "jobs_update",
                    "jobs": [
                        {
                            "id": job.id,
                            "status": job.status,
                            "progress": job.progress,
                            "updated_at": job.updated_at
                        }
                        for job in active_jobs
                    ]
                })
                await asyncio.sleep(2)
        except WebSocketDisconnect:
            print("Client disconnected")
    
    # Monta diretórios estáticos
    if VIDEO_DIR.exists():
        app.mount("/videos", StaticFiles(directory=str(VIDEO_DIR)), name="videos")
    
    if IMAGE_DIR.exists():
        app.mount("/images", StaticFiles(directory=str(IMAGE_DIR)), name="images")
    
    # Inicia workers quando a aplicação inicia
    @app.on_event("startup")
    async def startup_event():
        queue_manager.start_workers()
        VIDEO_DIR.mkdir(parents=True, exist_ok=True)
        IMAGE_DIR.mkdir(parents=True, exist_ok=True)
        print("✅ Aplicação iniciada com sucesso!")
    
    return app

# ============================================================
# PONTO DE ENTRADA
# ============================================================

if __name__ == "__main__":
    app = create_app()
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        log_level="info",
        workers=1,
        access_log=True
    )
