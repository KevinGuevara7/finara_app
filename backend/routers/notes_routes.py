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
    user = db.query(User).filter(User.name == "Kevin").first() or db.query(User).first()
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

@router.get("/", response_model=List[dict])
async def get_notes(db: Session = Depends(get_db)):
    user = db.query(User).filter(User.name == "Kevin").first() or db.query(User).first()
    return db.query(Note).filter(Note.user_id == user.id).all()

@router.put("/{note_id}")
async def update_note(note_id: int, data: NoteSchema, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404)
    note.title = data.title
    note.content = data.content
    note.category_name = data.category_name
    db.commit()
    return {"status": "updated"}

@router.delete("/{note_id}")
async def delete_note(note_id: int, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404)
    db.delete(note)
    db.commit()
    return {"status": "deleted"}