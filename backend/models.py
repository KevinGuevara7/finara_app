from sqlalchemy import Column, ForeignKey, Integer, String, DateTime, Float, Boolean
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime

# 1. TABLA DE CATEGORÍAS
class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    type = Column(String)

    user_id = Column(Integer, ForeignKey("users.id"))
    user = relationship("User")

    transactions = relationship("Transaction", back_populates="category")


# 2. TABLA DE ROLES
class Role(Base):
    __tablename__ = "roles"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True)
    users = relationship("User", back_populates="role")


# 3. TABLA DE USUARIOS
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    profile_image_url = Column(String, nullable=True)

    role_id = Column(Integer, ForeignKey("roles.id"))
    role = relationship("Role", back_populates="users")

    transactions = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    reset_tokens = relationship("PasswordResetToken", backref="user", cascade="all, delete-orphan")


# 4. TABLA DE TRANSACCIONES
class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    amount = Column(Float)
    type = Column(String)
    description = Column(String)

    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    user = relationship("User", back_populates="transactions")

    category_id = Column(Integer, ForeignKey("categories.id"))
    category = relationship("Category", back_populates="transactions")


# 5. RESET TOKEN
class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token = Column(String, unique=True, index=True)
    expires_at = Column(DateTime)

    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))

class VideoCategory(Base):
    __tablename__ = "video_categories"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String)
    description = Column(String)

    videos = relationship(
        "Video",
        back_populates="category",
        cascade="all, delete-orphan"
    )


class Video(Base):
    __tablename__ = "videos"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String)
    url = Column(String)

    category_id = Column(
        Integer,
        ForeignKey("video_categories.id", ondelete="CASCADE")
    )
    category = relationship("VideoCategory", back_populates="videos")


class Lectura(Base):
    __tablename__ = "lecturas"

    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String)
    contenido = Column(String)
    tiempo_lectura = Column(String)

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    content = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

    sender_id = Column(Integer, ForeignKey("users.id"))
    receiver_id = Column(Integer, ForeignKey("users.id"))

    is_read = Column(Boolean, default=False)

    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])

class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    content = Column(String, nullable=False)
    category_name = Column(String, default="General")
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)