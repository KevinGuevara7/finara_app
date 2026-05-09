# Importaciones
import os
import os
import shutil

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models  # ✅ Esto funciona porque models.py está en la misma raíz
from routers.user_routes import get_current_user
from database import SessionLocal
from models import User, PasswordResetToken
from security import hash_password, verify_password, create_reset_token, get_expiration
from email_utils import send_email
from datetime import datetime
from auth import create_access_token, require_admin
from pydantic import BaseModel
from fastapi import UploadFile, File
import schemas
import threading

from routers.user_routes import get_current_user
router = APIRouter(
    prefix="/auth",
    tags=["Auth"]
)

class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


# Entrega la sesión al endpoint que la necesite
def get_db():
    db = SessionLocal() # Abre una conexión temporal con PostgreSQL
    try:
        yield db
    finally:
        db.close()  # Cierra la conexión cuando termina la petición, evita problemas de rendimiento



# Endpoint de registro
@router.post("/register")  # Esto crea la ruta HTTP POST

# Aquí se trae a schemas.UserCreate que valida los datos con Pydantic desde schemas
# db: Session = Depends(get_db) dice a fastAPI "obtén una conexión a la base de datos usando get_db" 
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):

    existing_user = db.query(User).filter(User.email == user.email).first()

    if existing_user:
        return {"error": "El email ya está registrado"}

    # Contraseña encriptada
    hashed_password = hash_password(user.password)

# Creación de objeto usuario(User) usando los datos recibidos
    new_user = User(
        name=user.name,
        email=user.email,
        password=hashed_password,
        role_id=2
    )

    db.add(new_user)    # Agrega el usuario a la sesión
    db.commit() # Guarda los datos en PostgreSQL
    db.refresh(new_user)    # Actualiza el objeto con los datos finales guardados

    return {"message": "Usuario creado"}    # Respuesta del backend



# Endpoint de login
@router.post("/login") # Esto crea la ruta HTTP POST

# user: schemas.UserLogin significa que fastAPI espera un JSON con esa estructura creada en schemas
# db: Session = Depends(get_db) crea una conexión a la base de datos usando la función get_db
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):

# Aquí ocurre una consulta a PostgreSQL(db.query(User))
# Aquí se filtra el email por uno específico (.filter(User.email == user.email))
# Aquí devuelve el primer resultado encontrado (.first())
    db_user = db.query(User).filter(User.email == user.email).first()

# Verificar si existe usuario
    if not db_user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    
# Verificar si la contraseña es correcta (contraseña ingresada vs contraseña hash en db)
    if not verify_password(user.password, db_user.password):
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
    
# Crear el token JWT
# El token guarda email y rol
    access_token = create_access_token(
        data={
            "sub": db_user.email,
            "role": db_user.role.name
            }
    )

# Si todo está bien retorna el mensaje exitoso
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

@router.get("/admin-only")
def admin_only(data = Depends(require_admin)):
    return {"message": "Bienvenido admin"}


@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    
    user = db.query(User).filter(User.email == data.email).first()

    if not user:
        return {"msg": "Si existe, se enviará correo"}

    token = create_reset_token()

    reset = PasswordResetToken(
        user_id=user.id,
        token=token,
        expires_at=get_expiration()
    )

    db.add(reset)
    db.commit()
    db.refresh(reset)


    link = f"https://finara-api-1lmd.onrender.com/reset-password?token={token}"

    send_email(data.email, link)

    return {"msg": "Correo enviado"}




@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):

    reset = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == data.token
    ).first()

    if not reset or reset.expires_at < datetime.utcnow():
        return {"error": "Token invalido o expirado"}
    
    user = db.query(User).filter(User.id == reset.user_id).first()

    user.password = hash_password(data.new_password)

    db.delete(reset)
    db.commit()

    return {"msg": "Contraseña actualizada"}

@router.post("/upload-profile-picture")
async def upload_image(
    file: UploadFile = File(...), 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user) # Importante para saber de quién es la foto
):
    # 1. Crear carpeta si no existe
    if not os.path.exists("static/profile_pics"):
        os.makedirs("static/profile_pics")

    # 2. Nombre de archivo único para evitar que se sobrescriban
    extension = file.filename.split(".")[-1]
    file_name = f"user_{current_user.id}.{extension}"
    file_path = f"static/profile_pics/{file_name}"
    
    # 3. Guardar el archivo físicamente
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # 4. CREAR URL Y GUARDAR EN POSTGRESQL
    url_completa = f"https://finara-api-1lmd.onrender.com/{file_path}"
    
    current_user.profile_image_url = url_completa # Asignamos la URL al modelo del usuario
    db.add(current_user) # Aseguramos que SQLAlchemy lo siga
    db.commit() # ¡ESTO guarda la URL en la base de datos!
    db.refresh(current_user)
    
    return {"url": url_completa}