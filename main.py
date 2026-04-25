from typing import Any
from datetime import datetime, timedelta
import logging
import re
import json

from fastapi import FastAPI
from fastapi import HTTPException
from fastapi import Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from apscheduler.schedulers.background import BackgroundScheduler

from database import diet_collection, get_database_state, users_collection, workouts_collection, reports_collection, workout_plans_collection
from llm import (
    decode_goal_natural_language,
    generate_diet_plan_from_answers,
    generate_optimized_diet_plan,
    generate_optimized_workout_plan,
    generate_plan,
    generate_workout_plan_from_answers,
    generate_daily_summary,
    estimate_nutrition,
    generate_7_day_workout_plan,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s - %(message)s")
logger = logging.getLogger("fitness_backend.api")

# ----------------------------
# SCHEDULER SETUP
# ----------------------------

def daily_report_job():
    logger.info("Running scheduled daily report job")
    today = datetime.now().strftime("%Y-%m-%d")
    try:
        # Check if already exists to avoid duplicates
        if not reports_collection.find_one({"date": today}):
            _generate_and_store_report(today)
            logger.info("Scheduled report generated successfully for %s", today)
        else:
            logger.info("Report for %s already exists, skipping scheduled job", today)
    except Exception as e:
        logger.error("Failed in scheduled daily report job: %s", e)

scheduler = BackgroundScheduler()
scheduler.add_job(daily_report_job, 'cron', hour=23, minute=30)
scheduler.start()

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ----------------------------
# DATA MODELS
# ----------------------------

class Goal(BaseModel):
    name: str
    goal: str
    target_weight: int | None = None
    goal_type: str | None = None
    target_value: float | None = None
    target_unit: str | None = None


class Workout(BaseModel):
    exercise: str
    sets: int | None = None
    reps: int | None = None
    distance: float | None = None
    time: str | None = None
    duration: str | None = None


class Diet(BaseModel):
    food: str
    calories: int
    protein: int


class DietInput(BaseModel):
    food: str


class HumanGoalInput(BaseModel):
    text: str = Field(min_length=3)


class ChatAnswer(BaseModel):
    question: str
    answer: str


class PlanGenerationInput(BaseModel):
    goal: dict[str, Any] | None = None
    chat: list[ChatAnswer]


class WorkoutPlanRequest(BaseModel):
    goal: str
    location: str
    time_per_day: str
    experience: str
    preferences: str = ""


def _today_date_str() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def _date_str_days_ago(days: int) -> str:
    return (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")


def _iso_timestamp() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _latest_goal() -> dict[str, Any] | None:
    return users_collection.find_one({}, {"_id": 0}, sort=[("created_at", -1)])


def _logs_for_date(collection, date_str: str):
    return list(collection.find({"log_date": date_str}, {"_id": 0}, sort=[("created_at", 1)]))


WORKOUT_CHAT_QUESTIONS = [
    "What type of workout do you prefer (home, gym, mixed)?",
    "What exercises can you do comfortably right now? (e.g. pushups, situps, running)",
    "How many days per week can you train?",
    "How much time can you give per session (minutes)?",
    "Any injuries or movements to avoid?",
]


DIET_CHAT_QUESTIONS = [
    "What is your food preference? (veg, non-veg, eggetarian, vegan)",
    "How many meals can you take per day?",
    "Any allergies or foods you avoid?",
    "What is your daily routine like? (wake, work/college, sleep)",
    "What is your biggest diet challenge right now?",
]


# ----------------------------
# BASIC TEST ENDPOINT
# ----------------------------

@app.get("/")
def home():
    logger.info("Health check requested")
    return {"message": "AI Fitness Coach Backend Running"}


# ----------------------------
# SET USER GOAL
# ----------------------------

@app.post("/set-goal")
def set_goal(goal: Goal):
    logger.info("Incoming /set-goal payload=%s", goal.model_dump())

    try:
        goal_data = {
            "name": goal.name,
            "goal": goal.goal,
            "target_weight": goal.target_weight,
            "goal_type": goal.goal_type,
            "target_value": goal.target_value,
            "target_unit": goal.target_unit,
            "created_at": _iso_timestamp(),
        }

        result = users_collection.insert_one(goal_data)
        inserted_id = str(getattr(result, "inserted_id", ""))
        logger.info("/set-goal insert result inserted_id=%s", inserted_id)

        return {"message": "Goal saved successfully", "inserted_id": inserted_id}
    except Exception as exc:
        logger.exception("/set-goal failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to save goal: {exc}") from exc


@app.post("/decode-goal")
def decode_goal(payload: HumanGoalInput):
    logger.info("Decoding natural language goal: %s", payload.text)
    decoded = decode_goal_natural_language(payload.text)
    logger.info("Decoded goal: %s", decoded)
    return {"decoded_goal": decoded}


# ----------------------------
# LOG WORKOUT
# ----------------------------

@app.post("/log-workout")
def log_workout(workout: Workout):
    logger.info("Incoming /log-workout payload=%s", workout.model_dump())

    try:
        workout_data = {
            "exercise": workout.exercise,
            "sets": workout.sets,
            "reps": workout.reps,
            "distance": workout.distance,
            "time": workout.time,
            "duration": workout.duration,
            "log_date": _today_date_str(),
            "created_at": _iso_timestamp(),
        }

        result = workouts_collection.insert_one(workout_data)
        inserted_id = str(getattr(result, "inserted_id", ""))
        logger.info("/log-workout insert result inserted_id=%s", inserted_id)

        return {"message": "Workout logged successfully", "inserted_id": inserted_id}
    except Exception as exc:
        logger.exception("/log-workout failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to log workout: {exc}") from exc


# ----------------------------
# LOG DIET
# ----------------------------

@app.post("/log-diet")
def log_diet(diet_input: DietInput):
    logger.info("Incoming /log-diet food=%s", diet_input.food)

    try:
        # Automatically estimate calories and protein
        nutrition = estimate_nutrition(diet_input.food)
        
        diet_data = {
            "food": diet_input.food,
            "calories": nutrition["calories"],
            "protein": nutrition["protein"],
            "log_date": _today_date_str(),
            "created_at": _iso_timestamp(),
        }

        result = diet_collection.insert_one(diet_data)
        inserted_id = str(getattr(result, "inserted_id", ""))
        logger.info("/log-diet insert result inserted_id=%s, estimated=%s", inserted_id, nutrition)

        return {
            "message": "Diet logged successfully", 
            "inserted_id": inserted_id,
            "estimated_nutrition": nutrition
        }
    except Exception as exc:
        logger.exception("/log-diet failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to log diet: {exc}") from exc


# ----------------------------
# AI PLAN GENERATION
# ----------------------------

@app.get("/ai-plan")
def ai_plan():
    logger.info("Incoming /ai-plan request")

    try:
        user = _latest_goal()
        workouts = list(workouts_collection.find({}, {"_id": 0}))
        diet_logs = list(diet_collection.find({}, {"_id": 0}))

        logger.info("Fetched data for AI: goal=%s", user)
        logger.info("Fetched data for AI: workouts_count=%d", len(workouts))
        logger.info("Fetched data for AI: diet_count=%d", len(diet_logs))

        if user is None:
            raise HTTPException(status_code=404, detail="No goal found. Please call /set-goal first.")

        ai_response_raw = generate_plan(user, workouts, diet_logs)
        try:
            ai_response = json.loads(ai_response_raw)
        except Exception:
            ai_response = {"next_step": "Stick to your goal", "suggestion": ai_response_raw}

        return {
            "plan": ai_response,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("/ai-plan failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to generate AI plan: {exc}") from exc


@app.get("/debug")
def debug_data():
    logger.info("Incoming /debug request")

    try:
        goals = list(users_collection.find({}, {"_id": 0}, sort=[("created_at", -1)]))
        workouts = list(workouts_collection.find({}, {"_id": 0}, sort=[("created_at", -1)]))
        diet_logs = list(diet_collection.find({}, {"_id": 0}, sort=[("created_at", -1)]))
        db_state = get_database_state()

        return {
            "database": db_state,
            "goal": goals[0] if goals else None,
            "goals": goals,
            "workouts": workouts,
            "diet": diet_logs,
        }
    except Exception as exc:
        logger.exception("/debug failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to fetch debug data: {exc}") from exc


@app.get("/workout-chat-questions")
def workout_chat_questions():
    return {"questions": WORKOUT_CHAT_QUESTIONS}


@app.get("/diet-chat-questions")
def diet_chat_questions():
    return {"questions": DIET_CHAT_QUESTIONS}


@app.post("/generate-workout-plan-chat")
def generate_workout_plan(payload: PlanGenerationInput):
    logger.info("Generating workout plan from chat")
    effective_goal = payload.goal or _latest_goal()
    plan = generate_workout_plan_from_answers(
        goal=effective_goal,
        chat=[item.model_dump() for item in payload.chat],
    )
    return {"workout_plan": plan}


@app.post("/generate-diet-plan")
def generate_diet_plan(payload: PlanGenerationInput):
    logger.info("Generating diet plan from chat")
    effective_goal = payload.goal or _latest_goal()
    plan = generate_diet_plan_from_answers(
        goal=effective_goal,
        chat=[item.model_dump() for item in payload.chat],
    )
    return {"diet_plan": plan}


@app.get("/goal/latest")
def get_latest_goal_endpoint():
    return {"goal": _latest_goal()}


@app.post("/generate-workout-plan")
def create_workout_plan(req: WorkoutPlanRequest):
    logger.info("Generating 7-day workout plan for goal=%s", req.goal)
    try:
        plan_text = generate_7_day_workout_plan(
            goal=req.goal,
            location=req.location,
            time_per_day=req.time_per_day,
            experience=req.experience,
            preferences=req.preferences
        )
        
        # Store in DB
        plan_data = {
            "goal": req.goal,
            "location": req.location,
            "plan": plan_text,
            "created_at": _iso_timestamp()
        }
        workout_plans_collection.insert_one(plan_data)
        
        return {"plan": plan_text}
    except Exception as exc:
        logger.exception("Workout plan generation failed: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))


def _generate_and_store_report(date_str: str):
    logger.info("Generating persistent report for date: %s", date_str)
    workout_today = _logs_for_date(workouts_collection, date_str)
    diet_today = _logs_for_date(diet_collection, date_str)
    goal = _latest_goal()

    raw_summary = generate_daily_summary(
        goal=goal,
        workouts=workout_today,
        diet_logs=diet_today,
    )

    # Simple parsing logic for the structured output
    summary_part = "No summary generated."
    good_points = "No specific good points noted."
    improvements = "No improvements suggested."
    tomorrow_plan = "Keep going!"

    try:
        sections = re.split(r"\n- ", "\n" + raw_summary)
        for section in sections:
            if section.lower().startswith("summary"):
                summary_part = section.split("\n", 1)[-1].strip() if "\n" in section else section
            elif section.lower().startswith("good points"):
                good_points = section.split("\n", 1)[-1].strip() if "\n" in section else section
            elif section.lower().startswith("improvements"):
                improvements = section.split("\n", 1)[-1].strip() if "\n" in section else section
            elif section.lower().startswith("tomorrow plan"):
                tomorrow_plan = section.split("\n", 1)[-1].strip() if "\n" in section else section
    except Exception:
        summary_part = raw_summary

    report_data = {
        "date": date_str,
        "summary": summary_part,
        "good_points": good_points, # Adding this to match LLM output
        "improvements": improvements,
        "plan": tomorrow_plan,
        "raw_content": raw_summary,
        "created_at": _iso_timestamp()
    }

    reports_collection.insert_one(report_data)
    return report_data


@app.get("/report")
def get_report(date: str | None = Query(default=None)):
    logger.info("Incoming /report request for date: %s", date)
    target_date = date or _today_date_str()
    
    try:
        # Fetch logs
        workout_today = _logs_for_date(workouts_collection, target_date)
        diet_today = _logs_for_date(diet_collection, target_date)
        
        # Calculate totals
        total_cal = sum(d.get("calories", 0) for d in diet_today)
        total_pro = sum(d.get("protein", 0) for d in diet_today)

        # Check if report already exists in DB
        existing_report = reports_collection.find_one({"date": target_date}, {"_id": 0})
        
        if existing_report:
            logger.info("Found existing report for %s", target_date)
            return {
                "workouts": workout_today,
                "diet": diet_today,
                "total_calories": total_cal,
                "total_protein": total_pro,
                "ai_summary": existing_report["raw_content"]
            }

        # If not exists, generate it
        report = _generate_and_store_report(target_date)
        
        return {
            "workouts": workout_today,
            "diet": diet_today,
            "total_calories": total_cal,
            "total_protein": total_pro,
            "ai_summary": report["raw_content"]
        }
    except Exception as exc:
        logger.exception("/report failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to fetch/generate report: {exc}") from exc


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)