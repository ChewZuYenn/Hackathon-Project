from fastapi import FastAPI, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sympy import sympify, simplify
from sympy.parsing.latex import parse_latex
import base64
import os
import requests

app = FastAPI()

# Allow the Flutter app (especially Flutter Web) to call this API during development.
# If you deploy this, replace "*" with your real frontend URL(s).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Replace with your MathPix credentials (or set as environment variables).
MATHPIX_APP_ID = os.getenv("MATHPIX_APP_ID", "YOUR_APP_ID")
MATHPIX_APP_KEY = os.getenv("MATHPIX_APP_KEY", "YOUR_APP_KEY")

# Example correct answer (can be dynamic per question)
CORRECT_ANSWER = "(x + 1)**2"


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/submit-answer/")
async def submit_answer(
    file: UploadFile = File(...),
    correct_answer: str | None = Form(default=None),
):
    """
    Receive a handwritten answer image, send to MathPix to extract LaTeX,
    compare against expected answer using SymPy, and return feedback.
    """
    # Read image
    img_bytes = await file.read()
    img_base64 = base64.b64encode(img_bytes).decode()

    # If MathPix credentials are not configured, return a dummy response
    if MATHPIX_APP_ID == "YOUR_APP_ID" or MATHPIX_APP_KEY == "YOUR_APP_KEY":
        return {
            "latex": "",
            "correct": None,
            "feedback": "Backend connected! Configure MathPix keys to enable real math recognition.",
        }

    # Send to MathPix API
    headers = {
        "app_id": MATHPIX_APP_ID,
        "app_key": MATHPIX_APP_KEY,
        "Content-type": "application/json",
    }
    data = {
        "src": f"data:image/png;base64,{img_base64}",
        "formats": ["text"],
        "data_options": {"include_asciimath": False},
    }

    try:
        response = requests.post(
            "https://api.mathpix.com/v3/text", headers=headers, json=data, timeout=15
        )
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"Error calling MathPix: {str(e)}"},
        )

    if response.status_code != 200:
        return JSONResponse(
            status_code=500,
            content={"error": "MathPix API error", "details": response.text},
        )

    latex_text = response.json().get("text", "").strip()

    if not latex_text:
        return {
            "latex": "",
            "correct": None,
            "feedback": "Could not read your answer. Try writing more clearly.",
        }

    try:
        # Parse LaTeX to SymPy expression
        student_expr = parse_latex(latex_text)
        expected = correct_answer if correct_answer else CORRECT_ANSWER
        correct_expr = sympify(expected)

        # Compare
        is_correct = simplify(student_expr - correct_expr) == 0
        if is_correct:
            feedback = "Correct! Well done."
        else:
            feedback = "Incorrect. Check your factoring and try again."
    except Exception as e:
        return {
            "latex": latex_text,
            "correct": None,
            "feedback": f"Error processing your answer: {str(e)}",
        }

    return {"latex": latex_text, "correct": is_correct, "feedback": feedback}
