from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from auth import verify_token
from database import SessionLocal
from models import Category, User
import schemas
import models

router = APIRouter(
    prefix="/categories",
    tags=["Categories"]
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/")
def get_categories(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    try:
        data = verify_token(token)

        user = db.query(User).filter(User.email == data["sub"]).first()

        if not user:
            return {"error": "Usuario no encontrado"}

        categories = db.query(Category).filter(
            Category.user_id == user.id
        ).all()

        return categories

    except Exception as e:
        return {"error": str(e)}


@router.post("/")
def create_category(
    category: schemas.CategoryCreate,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    data = verify_token(token)
    user = db.query(User).filter(User.email == data["sub"]).first()

    new_category = Category(
        name=category.name,
        type=category.type,
        user_id=user.id
    )

    db.add(new_category)
    db.commit()
    db.refresh(new_category)

    return new_category

# --- ACTUALIZAR CATEGORÍA ---
@router.put("/{category_id}")
def update_category(
    category_id: int,
    category_data: schemas.CategoryCreate,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    data = verify_token(token)
    user = db.query(User).filter(User.email == data["sub"]).first()
    
    db_category = db.query(Category).filter(
        Category.id == category_id, 
        Category.user_id == user.id
    ).first()

    if not db_category:
        return {"error": "Categoría no encontrada"}

    db_category.name = category_data.name
    db_category.type = category_data.type
    
    db.commit()
    db.refresh(db_category)
    return db_category

# --- ELIMINAR CATEGORÍA ---
@router.delete("/{category_id}")
def delete_category(
    category_id: int, 
    token: str = Depends(oauth2_scheme), 
    db: Session = Depends(get_db)
):
    data = verify_token(token)
    user = db.query(models.User).filter(models.User.email == data["sub"]).first()

    # USAMOS models.Category (la de transacciones)
    db_category = db.query(models.Category).filter(
        models.Category.id == category_id,
        models.Category.user_id == user.id
    ).first()

    if not db_category:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")

    db.delete(db_category)
    db.commit()
    return {"message": "Categoría eliminada"}
