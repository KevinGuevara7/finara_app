from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Note, User
from pydantic import BaseModel
from typing import List

router = APIRouter(prefix="/notes", tags=["Notas"])

class NoteSchema(BaseModel):
    title: str
    content: str
    category_name: str = "General"

@router.post("/")
async def create_note(data: NoteSchema, db: Session = Depends(get_db)):
    # Buscamos al usuario 'Kevin' o al primero disponible para asignar la nota
    user = db.query(User).filter(User.name == "Kevin").first() or db.query(User).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado para asignar la nota")

    new_note = Note(
        title=data.title,
        content=data.content,
        category_name=data.category_name,
        user_id=user.id
    )
    db.add(new_note)
    db.commit()
    db.refresh(new_note)
    return new_note

@router.get("/")
async def get_notes(db: Session = Depends(get_db)):
    user = db.query(User).filter(User.name == "Kevin").first() or db.query(User).first()
    
    if not user:
        return []
        
    return db.query(Note).filter(Note.user_id == user.id).all()

# Se agrega "/" al final para consistencia con el prefijo y evitar errores de redirección
@router.put("/{note_id}/")
async def update_note(note_id: int, data: NoteSchema, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Nota no encontrada")
        
    note.title = data.title
    note.content = data.content
    note.category_name = data.category_name
    
    db.commit()
    db.refresh(note)
    return note

# Se agrega "/" al final para evitar el error 307 en peticiones DELETE
@router.delete("/{note_id}/")
async def delete_note(note_id: int, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Nota no encontrada")
        
    db.delete(note)
    db.commit()
    return {"status": "deleted", "id": note_id}