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
# Project Structure
calibration_app/
├── app.py
├── templates/
│   ├── index.html
│   ├── layout.html
│   ├── admin_sessions.html
│   └── ... (other HTML files)
└── static/
    ├── css/
    ├── js/
    └── images/
