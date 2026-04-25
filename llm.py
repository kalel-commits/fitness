import json
import logging
import os
import re
from typing import Any
from urllib import error, request

logger = logging.getLogger("fitness_backend.llm")

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
LLAMA_MODEL = os.getenv("LLAMA_MODEL", "llama3")


def _clean_text_output(text: str) -> str:
	cleaned = text.replace("\r\n", "\n").strip()
	cleaned = re.sub(r"```[\s\S]*?```", lambda m: m.group(0).strip(), cleaned)
	cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
	return cleaned.strip()


def _safe_float(text: str) -> float | None:
	match = re.search(r"(\d+(?:\.\d+)?)", text)
	if not match:
		return None
	return float(match.group(1))


def _extract_json_block(text: str) -> dict[str, Any] | None:
	match = re.search(r"\{[\s\S]*\}", text)
	if not match:
		return None
	try:
		return json.loads(match.group(0))
	except Exception:
		return None


def _call_llama(system_prompt: str, user_prompt: str) -> str | None:
	try:
		payload_dict = {
			"model": LLAMA_MODEL,
			"prompt": f"System: {system_prompt}\n\nUser: {user_prompt}",
			"stream": False,
		}
		payload = json.dumps(payload_dict).encode("utf-8")
		logger.info("Calling Ollama endpoint=%s/api/generate model=%s", OLLAMA_BASE_URL, LLAMA_MODEL)
		req = request.Request(
			f"{OLLAMA_BASE_URL}/api/generate",
			data=payload,
			headers={"Content-Type": "application/json"},
			method="POST",
		)
		with request.urlopen(req, timeout=300) as resp:
			if resp.status < 200 or resp.status >= 300:
				logger.error("Ollama returned non-2xx status=%s", resp.status)
				return None
			raw = resp.read().decode("utf-8")
		parsed = json.loads(raw)
		text = parsed.get("response")
		if not isinstance(text, str) or not text.strip():
			logger.error("Ollama response missing 'response' text field")
			return None
		return _clean_text_output(text)
	except (error.URLError, TimeoutError, json.JSONDecodeError, ValueError) as exc:
		logger.exception("Failed calling Ollama: %s", exc)
		return None


def estimate_nutrition(food_text: str) -> dict[str, Any]:
	"""
	Estimates calories and protein from food text using Ollama (Llama3).
	"""
	print(f"--- AI Nutrition Estimation ---")
	print(f"Input Food: {food_text}")
	
	prompt = (
		"You are a nutrition expert.\n"
		f"Food: {food_text}\n"
		"Estimate calories (kcal) and protein (grams).\n"
		"Return ONLY JSON in this format: "
		"{\"calories\": number, \"protein\": number}"
	)
	
	try:
		raw_output = _call_llama("You are a strict JSON nutrition assistant.", prompt)
		print(f"AI Raw Response: {raw_output}")
		
		if raw_output:
			# Extraction using regex for robustness
			json_data = _extract_json_block(raw_output)
			if json_data:
				cal = json_data.get("calories", 0)
				pro = json_data.get("protein", 0)
				print(f"Parsed JSON: {json_data}")
				return {"calories": cal, "protein": pro}
	except Exception as e:
		print(f"AI Estimation Error: {e}")

	# Fallback (Generic values for a small meal if AI fails)
	print("Using Fallback values (250 kcal, 10g protein)")
	return {"calories": 250, "protein": 10}


def _decode_goal_fallback(text: str) -> dict[str, Any]:
	source = text.strip()
	lowered = source.lower()

	goal_type = "general_fitness"
	normalized_goal = "Improve overall fitness"
	target_value = _safe_float(lowered)
	target_unit = None
	target_weight = None

	if "gain" in lowered and "weight" in lowered:
		goal_type = "weight_gain"
		target_unit = "kg" if "kg" in lowered else "lb" if "lb" in lowered else None
		normalized_goal = "Gain healthy body weight"
		if target_value is not None and target_unit == "kg":
			target_weight = int(round(target_value))
	elif "lose" in lowered and "weight" in lowered:
		goal_type = "weight_loss"
		target_unit = "kg" if "kg" in lowered else "lb" if "lb" in lowered else None
		normalized_goal = "Reduce body weight safely"
		if target_value is not None and target_unit == "kg":
			target_weight = int(round(target_value))
	elif "stamina" in lowered or "endurance" in lowered or "run" in lowered:
		goal_type = "endurance"
		target_unit = "km" if "km" in lowered else "minutes" if "minute" in lowered else None
		normalized_goal = "Improve stamina and endurance"
	elif "6 pack" in lowered or "abs" in lowered or "six pack" in lowered:
		goal_type = "body_recomposition"
		normalized_goal = "Build visible abs and reduce body fat"
	elif "muscle" in lowered or "strength" in lowered:
		goal_type = "muscle_gain"
		normalized_goal = "Increase muscle mass and strength"

	summary = normalized_goal
	if target_value is not None and target_unit is not None:
		summary = f"{normalized_goal} (target: {target_value:g} {target_unit})"

	return {
		"raw_text": source,
		"goal_type": goal_type,
		"normalized_goal": normalized_goal,
		"target_value": target_value,
		"target_unit": target_unit,
		"target_weight": target_weight,
		"summary": summary,
	}


def decode_goal_natural_language(text: str) -> dict[str, Any]:
	clean = text.strip()
	system = (
		"You are a fitness goal parser. Return only valid JSON with keys: "
		"goal_type, normalized_goal, target_value, target_unit, target_weight, summary."
	)
	user = (
		"Parse this goal: "
		f"{clean}\n"
		"Use goal_type values like: weight_gain, weight_loss, endurance, body_recomposition, muscle_gain, general_fitness."
	)

	llama_output = _call_llama(system, user)
	if llama_output:
		parsed = _extract_json_block(llama_output)
		if parsed:
			parsed.setdefault("goal_type", "general_fitness")
			parsed.setdefault("normalized_goal", "Improve overall fitness")
			parsed.setdefault("target_value", None)
			parsed.setdefault("target_unit", None)
			parsed.setdefault("target_weight", None)
			parsed.setdefault("summary", parsed["normalized_goal"])
			parsed["raw_text"] = clean
			return parsed

	return _decode_goal_fallback(clean)


def _chat_to_map(chat: list[dict[str, str]]) -> dict[str, str]:
	result: dict[str, str] = {}
	for item in chat:
		q = item.get("question", "").strip()
		a = item.get("answer", "").strip()
		if q:
			result[q] = a
	return result


def _history_summary(rows: list[dict[str, Any]], kind: str) -> str:
	if not rows:
		return f"No {kind} logs."
	if kind == "workout":
		total_sets = sum(int(row.get("sets", 0)) for row in rows)
		total_reps = sum(int(row.get("reps", 0)) for row in rows)
		return f"{len(rows)} sessions, total {total_sets} sets, {total_reps} reps"
	total_cal = sum(int(row.get("calories", 0)) for row in rows)
	total_protein = sum(int(row.get("protein", 0)) for row in rows)
	return f"{len(rows)} meals, total {total_cal} kcal, {total_protein} g protein"


def generate_workout_plan_from_answers(goal: dict[str, Any] | None, chat: list[dict[str, str]]) -> str:
	chat_map = _chat_to_map(chat)

	goal_text = "Improve fitness"
	if goal:
		goal_text = (
			goal.get("goal")
			or goal.get("normalized_goal")
			or goal.get("summary")
			or goal_text
		)

	workout_type = chat_map.get("What type of workout do you prefer (home, gym, mixed)?", "mixed")
	exercises = chat_map.get(
		"What exercises can you do comfortably right now? (e.g. pushups, situps, running)",
		"pushups, squats, situps, running",
	)
	days = chat_map.get("How many days per week can you train?", "4")
	time_per_session = chat_map.get("How much time can you give per session (minutes)?", "45")
	restrictions = chat_map.get("Any injuries or movements to avoid?", "none")

	prompt = (
		f"Goal Focus: {goal_text}\n"
		f"Workout Style: {workout_type}\n"
		f"Available Exercises: {exercises}\n"
		f"Frequency: {days} days/week\n"
		f"Session Length: {time_per_session} minutes\n"
		f"Injury Notes: {restrictions}\n\n"
		"Generate a practical weekly workout plan with days, sets, reps or duration, and progression for next week."
	)

	llama_output = _call_llama(
		"You are an expert fitness coach. Give concise, safe, personalized workout plan.",
		prompt,
	)
	if llama_output:
		return llama_output

	return (
		"Weekly Plan:\n"
		"Day 1: Upper body + core (pushups, plank, shoulder work)\n"
		"Day 2: Lower body + mobility (squats, lunges, stretching)\n"
		"Day 3: Cardio intervals (run/walk cycles or cycling)\n"
		"Day 4: Full body circuit + core finisher\n"
		"Optional Day 5: Light cardio + mobility recovery\n\n"
		"Progression:\n"
		"- Increase reps by 2-3 each week for bodyweight movements\n"
		"- Increase total running time or distance by 8-10% weekly\n"
		"- Keep 1-2 rest days each week for recovery"
	)


def generate_diet_plan_from_answers(goal: dict[str, Any] | None, chat: list[dict[str, str]]) -> str:
	chat_map = _chat_to_map(chat)

	goal_text = "Improve fitness"
	if goal:
		goal_text = (
			goal.get("goal")
			or goal.get("normalized_goal")
			or goal.get("summary")
			or goal_text
		)

	food_pref = chat_map.get("What is your food preference? (veg, non-veg, eggetarian, vegan)", "mixed")
	meals = chat_map.get("How many meals can you take per day?", "4")
	allergies = chat_map.get("Any allergies or foods you avoid?", "none")
	routine = chat_map.get("What is your daily routine like? (wake, work/college, sleep)", "standard")
	challenge = chat_map.get("What is your biggest diet challenge right now?", "consistency")

	prompt = (
		f"Goal Focus: {goal_text}\n"
		f"Food Preference: {food_pref}\n"
		f"Meals Per Day: {meals}\n"
		f"Avoid/Allergy Notes: {allergies}\n"
		f"Routine: {routine}\n"
		f"Primary Challenge: {challenge}\n\n"
		"Generate a practical diet plan with meal examples, timing, and small adjustments for consistency."
	)

	llama_output = _call_llama(
		"You are an expert sports nutrition coach. Give concise, safe, personalized diet plan.",
		prompt,
	)
	if llama_output:
		return llama_output

	return (
		"Diet Structure:\n"
		"1) Breakfast: protein source + complex carbs + fruit\n"
		"2) Lunch: balanced plate (protein, vegetables, carbs)\n"
		"3) Snack: high-protein snack with hydration\n"
		"4) Dinner: lighter carbs, high protein, fiber-rich vegetables\n\n"
		"Practical Rules:\n"
		"- Target protein in each meal\n"
		"- Drink water steadily through the day\n"
		"- Keep one planned flexible meal weekly to improve adherence\n"
		"- Prepare 1-2 meals in advance on busy days"
	)


def generate_optimized_workout_plan(
	goal: dict[str, Any] | None,
	workout_yesterday: list[dict[str, Any]],
	workout_today: list[dict[str, Any]],
	diet_yesterday: list[dict[str, Any]],
	diet_today: list[dict[str, Any]],
) -> str:
	goal_text = (goal or {}).get("goal") or (goal or {}).get("summary") or "Improve fitness"
	prompt = (
		f"Goal: {goal_text}\n"
		f"Workout yesterday: {_history_summary(workout_yesterday, 'workout')}\n"
		f"Workout today: {_history_summary(workout_today, 'workout')}\n"
		f"Diet yesterday: {_history_summary(diet_yesterday, 'diet')}\n"
		f"Diet today: {_history_summary(diet_today, 'diet')}\n\n"
		"Give today's optimized workout plan with minute changes from previous pattern."
	)

	llama_output = _call_llama(
		"You are a fitness coach optimizing daily training based on yesterday and today progress.",
		prompt,
	)
	if llama_output:
		return llama_output

	return (
		"Today's Optimized Workout Plan\n"
		"- Keep warm-up 8 minutes + mobility 5 minutes\n"
		"- Increase one main exercise by 1 set compared to usual\n"
		"- Add 10-minute low-impact cardio finisher\n"
		"- Cooldown and breathing 6 minutes"
	)


def generate_optimized_diet_plan(
	goal: dict[str, Any] | None,
	workout_yesterday: list[dict[str, Any]],
	workout_today: list[dict[str, Any]],
	diet_yesterday: list[dict[str, Any]],
	diet_today: list[dict[str, Any]],
) -> str:
	goal_text = (goal or {}).get("goal") or (goal or {}).get("summary") or "Improve fitness"
	prompt = (
		f"Goal: {goal_text}\n"
		f"Workout yesterday: {_history_summary(workout_yesterday, 'workout')}\n"
		f"Workout today: {_history_summary(workout_today, 'workout')}\n"
		f"Diet yesterday: {_history_summary(diet_yesterday, 'diet')}\n"
		f"Diet today: {_history_summary(diet_today, 'diet')}\n\n"
		"Give today's optimized diet plan with minute changes from previous pattern."
	)

	llama_output = _call_llama(
		"You are a sports nutrition coach optimizing daily diet based on progress logs.",
		prompt,
	)
	if llama_output:
		return llama_output

	return (
		"Today's Optimized Diet Plan\n"
		"- Add one high-protein snack in afternoon\n"
		"- Shift heavier carbs near workout window\n"
		"- Keep dinner lighter and fiber-rich\n"
		"- Hydration target: at least 2.5 liters"
	)


def generate_plan(
	goal: dict[str, Any] | None,
	workouts: list[dict[str, Any]],
	diet_logs: list[dict[str, Any]],
) -> str:
	goal_text = (goal or {}).get("goal") or (goal or {}).get("summary") or "Improve fitness"
	
	workouts_str = json.dumps(workouts, indent=2) if workouts else "No workout history"
	diet_str = json.dumps(diet_logs, indent=2) if diet_logs else "No diet logs"

	prompt = (
		"You are a fitness expert.\n"
		"Based on the following user data:\n"
		f"Goal: {goal_text}\n"
		f"Workouts: {workouts_str}\n"
		f"Diet: {diet_str}\n\n"
		"Return ONLY JSON in this format: "
		"{\"next_step\": \"one specific exercise or action\", \"suggestion\": \"brief motivation/tip\"}"
	)

	print(f"--- Prompt sent to LLM ---\n{prompt}\n--------------------------")

	try:
		payload = {
			"model": "llama3",
			"prompt": prompt,
			"stream": False
		}
		data = json.dumps(payload).encode("utf-8")
		
		req = request.Request(
			"http://localhost:11434/api/generate",
			data=data,
			headers={"Content-Type": "application/json"},
			method="POST"
		)
		
		with request.urlopen(req, timeout=40) as response:
			if response.status == 200:
				raw_response = response.read().decode("utf-8")
				parsed = json.loads(raw_response)
				llm_response = parsed.get("response", "").strip()
				
				print(f"--- Response received ---\n{llm_response}\n-------------------------")
				
				json_data = _extract_json_block(llm_response)
				if json_data:
					return json.dumps(json_data)
				elif llm_response:
					return json.dumps({"next_step": "Stick to the plan", "suggestion": llm_response})
	except Exception as e:
		print(f"Error calling Ollama API: {e}")

	return json.dumps({
		"next_step": "30-min full body workout",
		"suggestion": "Stay consistent and stay hydrated!"
	})

	print("No data received from LLM, returning default fallback advice.")
	return (
		"1. Next workout plan: Do a 30-minute full body workout (pushups, squats, planks) 3-4 times a week.\n"
		"2. Diet improvement advice: Eat a balanced diet rich in protein and drink at least 2 liters of water daily.\n"
		"3. Tips to reach goal faster: Stay consistent, track your progress, and get 7-8 hours of sleep per night."
	)


def generate_daily_summary(
    goal: dict[str, Any] | None,
    workouts: list[dict[str, Any]],
    diet_logs: list[dict[str, Any]],
) -> str:
    """Generates a humanized summary of the day's progress."""
    goal_text = (goal or {}).get("goal") or (goal or {}).get("summary") or "Improve fitness"
    
    workouts_str = json.dumps(workouts, indent=2) if workouts else "No workout history"
    diet_str = json.dumps(diet_logs, indent=2) if diet_logs else "No diet logs"

    prompt = (
        f"User Goals: {goal_text}\n"
        f"Workouts: {workouts_str}\n"
        f"Diet: {diet_str}\n\n"
        "Analyze:\n"
        "1. What did user do today?\n"
        "2. Was it helpful?\n"
        "3. What is missing?\n"
        "4. 3 specific improvements\n"
        "5. Tomorrow plan\n\n"
        "Be specific and use numbers. Be motivational but realistic."
    )

    print(f"--- Summary Prompt Sent to LLM ---\n{prompt}\n--------------------------")

    try:
        payload = {
            "model": "llama3",
            "prompt": prompt,
            "stream": False
        }
        data = json.dumps(payload).encode("utf-8")
        
        req = request.Request(
            "http://localhost:11434/api/generate",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        
        with request.urlopen(req, timeout=300) as response:
            if response.status == 200:
                raw_response = response.read().decode("utf-8")
                parsed = json.loads(raw_response)
                llm_response = parsed.get("response", "").strip()
                
                print(f"--- Summary Response received ---\n{llm_response}\n-------------------------")
                
                if llm_response:
                    return llm_response
    except Exception as e:
        print(f"Error calling Ollama API for summary: {e}")

def generate_7_day_workout_plan(
    goal: str,
    location: str,
    time_per_day: str,
    experience: str,
    preferences: str
) -> str:
    """Generates a structured 7-day workout plan using AI."""
    print(f"--- Generating 7-Day Workout Plan ---")
    print(f"Goal: {goal}, Location: {location}, Time: {time_per_day}")

    prompt = (
        "You are a professional fitness coach.\n\n"
        "User Profile:\n"
        f"Goal: {goal}\n"
        f"Location: {location}\n"
        f"Time per day: {time_per_day}\n"
        f"Experience: {experience}\n"
        f"Preferences: {preferences}\n\n"
        "Create a concise 7-day workout plan.\n\n"
        "Format: Day X: Exercise (Sets x Reps/Time). Max 5 exercises per day.\n"
        "Format clearly day-wise. Be motivational and specific."
    )

    result = _call_llama("You are a professional fitness coach designing custom weekly plans.", prompt)
    if result:
        return result

    return "Rest Day - Please check your connection and try generating your plan again."
