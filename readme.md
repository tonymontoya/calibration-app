# How It Works

## Admin Side:
 - The admin visits /admin/sessions to see all sessions and can create a new one at /admin/session/new.
 - Once a session is created, the admin can upload employee performance data (CSV or Excel) via /admin/session/<session_id>/upload.
 - The session is started (made “active”) at /admin/session/<session_id>/start so that contributors can join using a unique URL.
 - During the session, the admin can review live vote counts, update employee details, and eventually end the session with /admin/session/<session_id>/end.
 - Finally, the results can be exported as a CSV from /admin/session/<session_id>/export.

## Contributor Side:
 - A manager (contributor) registers for a session at /session/<session_id>/register by providing their first and last name.
 - Once registered, they are taken to the main calibration interface (e.g. /session/<session_id>/contributor/<contributor_id>) where employees are grouped by level.
 - The contributor selects from drop‑down options (e.g. “Agree”, “Move up”, etc.) for both calibration rating and promotion offered. Their votes are saved and the interface shows a live tally of votes per option.
# How to Build and Run

## Build the Container
`docker build -t calibration_app .`

## Run the Container
`docker run -p 8000:8000 calibration_app`
This maps port 8000 on your host machine to port 8000 in the container, allowing you to access the application at http://localhost:8000.

## Notes
	•	SQLite vs. PostgreSQL:
The provided code uses SQLite (via the URI sqlite:///calibration.db) by default. If you plan to use PostgreSQL, consider one of the following:
	•	Update your app.config['SQLALCHEMY_DATABASE_URI'] in app.py to point to your PostgreSQL database.
	•	Use Docker Compose to stand up both your web application and a PostgreSQL container.
