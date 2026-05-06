from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine
from fastapi import UploadFile, File
from sqlalchemy.orm import Session
from fastapi import Depends
from database import get_db
from sqlalchemy.orm import Session
import models  # IMPORTANTE para registrar modelos
import shutil
import os
from routers import auth_routes, user_routes, transaction_routes, video_routes, lecturas_routes, stock_routes, category_routes


# 1. Crear la aplicación backend
app = FastAPI(
    title="Finara API",
    version="1.0"
)

# 2. CONFIGURACIÓN DE CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todas las fuentes (en producción, especifica tu frontend)
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


from routers import (
    auth_routes, 
    user_routes, 
    transaction_routes, 
    video_routes, 
    lecturas_routes, 
    stock_routes,
    category_routes
)

from routers.news_routes import news_router



# 3. Crear las tablas en la base de datos
models.Base.metadata.create_all(bind=engine)

# 4. Agregar rutas
app.include_router(auth_routes.router)
app.include_router(user_routes.router)
app.include_router(transaction_routes.router)
app.include_router(category_routes.router)
app.include_router(news_router)
app.include_router(video_routes.router)
app.include_router(lecturas_routes.router)
app.include_router(stock_routes.stock_router)

# Ruta raíz (para probar que funciona)
@app.get("/")
def read_root():
    return {"message": "Finara API is running"}

# Carpeta donde se guardarán las fotos
UPLOAD_DIR = "static/profile_pics"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# IMPORTANTE: Cambié @router por @app
@app.post("/users/upload-profile-picture")
async def upload_picture(
    file: UploadFile = File(...), 
    db: Session = Depends(get_db),
    # Usamos el método que ya tienes en user_routes para validar el token
    current_user: models.User = Depends(user_routes.get_current_user) 
):
    # Creamos el nombre del archivo
    file_name = f"{current_user.id}_{file.filename}"
    file_path = os.path.join(UPLOAD_DIR, file_name)
    
    # Guardar el archivo físicamente
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Generar la URL (Cambia esto por tu URL real de Render cuando hagas push)
    base_url = "https://finara-app.onrender.com" 
    url = f"{base_url}/{file_path}"
    
    # Guardar en la base de datos
    current_user.profile_image_url = url
    db.commit()
    db.refresh(current_user)
    
    return {"url": url}

# ESTO ES VITAL: Para que las fotos se puedan ver desde el navegador/Flutter
from fastapi.staticfiles import StaticFiles
app.mount("/static", StaticFiles(directory="static"), name="static")