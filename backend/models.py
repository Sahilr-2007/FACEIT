from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Date, ForeignKey
from database import Base
import datetime

class ScanHistory(Base):
    """For Disease Detector"""
    __tablename__ = "scan_history"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(DateTime, default=datetime.datetime.utcnow)
    condition = Column(String, index=True)
    confidence = Column(Float)
    message = Column(String)
    symptoms = Column(String) # Stored as stringified JSON

class FaceScanHistory(Base):
    """For Face Analyzer / Looksmaxxing PSL Score"""
    __tablename__ = "facescan_history"

    id = Column(Integer, primary_key=True, index=True)
    symmetry = Column(Float, default=0.0)
    jawline = Column(Float, default=0.0)
    eyes = Column(Float, default=0.0)
    cheekbones = Column(Float, default=0.0)
    midface = Column(Float, default=0.0)
    lower_face = Column(Float, default=0.0)
    skin_clarity = Column(Float, default=80.0)
    future_psl_score = Column(Float, default=0.0)
    future_improvements = Column(String, default="[]") # Stored as stringified JSON
    transformation_tips = Column(String, default="[]") # Stored as stringified JSON
    psl_score = Column(Float, default=0.0) # 1-10 Scale
    overall_message = Column(String, default="")
    date = Column(DateTime, default=datetime.datetime.utcnow)

class HabitTracker(Base):
    """For Dashboard Streaks and Habits"""
    __tablename__ = "habit_tracker"
    
    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, default=datetime.date.today, unique=True, index=True)
    drank_water = Column(Boolean, default=False)
    applied_spf = Column(Boolean, default=False)
    ate_clean = Column(Boolean, default=False)

class ChatHistory(Base):
    """For Aura Coach"""
    __tablename__ = "chat_history"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(DateTime, default=datetime.datetime.utcnow)
    sender = Column(String) # 'user' or 'bot'
    message = Column(String)

class CustomHabit(Base):
    """User-defined custom daily habits"""
    __tablename__ = "custom_habits"

    id = Column(Integer, primary_key=True, index=True)
    label = Column(String, nullable=False)
    icon_name = Column(String, default="check_circle")

class CustomHabitLog(Base):
    """Tracks daily completion of custom habits"""
    __tablename__ = "custom_habit_logs"

    id = Column(Integer, primary_key=True, index=True)
    habit_id = Column(Integer, ForeignKey("custom_habits.id", ondelete="CASCADE"), nullable=False, index=True)
    date = Column(Date, default=datetime.date.today, index=True)
