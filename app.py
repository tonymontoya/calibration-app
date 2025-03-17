from flask import Flask, render_template, request, redirect, url_for, flash, send_file, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func
import os, io, csv
import pandas as pd

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///calibration.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# ---------------------------
# Database Models
# ---------------------------
class CalibrationSession(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    session_name = db.Column(db.String(100), nullable=False)
    fiscal_year = db.Column(db.String(10), nullable=False)
    admin_name = db.Column(db.String(100), nullable=False)
    status = db.Column(db.String(20), default='created')  # created, active, or closed
    employees = db.relationship('Employee', backref='session', lazy=True)
    contributors = db.relationship('Contributor', backref='session', lazy=True)

class Employee(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey('calibration_session.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    level = db.Column(db.String(50), nullable=False)
    calibration_rating = db.Column(db.String(50), nullable=False)
    promotion_offered = db.Column(db.String(50), nullable=False)
    votes = db.relationship('Vote', backref='employee', lazy=True)

class Contributor(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey('calibration_session.id'), nullable=False)
    first_name = db.Column(db.String(50), nullable=False)
    last_name = db.Column(db.String(50), nullable=False)
    votes = db.relationship('Vote', backref='contributor', lazy=True)

class Vote(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    contributor_id = db.Column(db.Integer, db.ForeignKey('contributor.id'), nullable=False)
    employee_id = db.Column(db.Integer, db.ForeignKey('employee.id'), nullable=False)
    calibration_action = db.Column(db.String(20), nullable=False)  # Agree, Move up, Move down, No opinion
    promotion_action = db.Column(db.String(20), nullable=False)    # Agree, Disagree, No opinion

@app.before_first_request
def create_tables():
    db.create_all()

# ---------------------------
# Admin Routes
# ---------------------------
@app.route('/')
def home():
    return render_template('index.html')

@app.route('/admin/sessions')
def admin_sessions():
    sessions = CalibrationSession.query.all()
    return render_template('admin_sessions.html', sessions=sessions)

@app.route('/admin/session/new', methods=['GET', 'POST'])
def new_session():
    if request.method == 'POST':
        session_name = request.form.get('session_name')
        fiscal_year = request.form.get('fiscal_year')
        admin_name = request.form.get('admin_name')
        new_sess = CalibrationSession(session_name=session_name, fiscal_year=fiscal_year, admin_name=admin_name)
        db.session.add(new_sess)
        db.session.commit()
        flash('Session created successfully!', 'success')
        return redirect(url_for('admin_sessions'))
    return render_template('new_session.html')

@app.route('/admin/session/<int:session_id>', methods=['GET', 'POST'])
def manage_session(session_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    if request.method == 'POST':
        # Update employee records inline
        for emp in session_obj.employees:
            emp.name = request.form.get(f'name_{emp.id}', emp.name)
            emp.level = request.form.get(f'level_{emp.id}', emp.level)
            emp.calibration_rating = request.form.get(f'cal_rating_{emp.id}', emp.calibration_rating)
            emp.promotion_offered = request.form.get(f'promo_{emp.id}', emp.promotion_offered)
        db.session.commit()
        flash('Employee records updated!', 'success')
        return redirect(url_for('manage_session', session_id=session_id))
    vote_data = {}
    for emp in session_obj.employees:
        cal_votes = db.session.query(Vote.calibration_action, func.count(Vote.id)).filter(Vote.employee_id == emp.id).group_by(Vote.calibration_action).all()
        promo_votes = db.session.query(Vote.promotion_action, func.count(Vote.id)).filter(Vote.employee_id == emp.id).group_by(Vote.promotion_action).all()
        vote_data[emp.id] = {
            'calibration': dict(cal_votes),
            'promotion': dict(promo_votes)
        }
    return render_template('manage_session.html', session=session_obj, vote_data=vote_data)

@app.route('/admin/session/<int:session_id>/upload', methods=['GET', 'POST'])
def upload_employees(session_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    if request.method == 'POST':
        file = request.files.get('file')
        if not file:
            flash('No file uploaded', 'danger')
            return redirect(request.url)
        if file.filename.endswith('.csv'):
            stream = io.StringIO(file.stream.read().decode("UTF8"), newline=None)
            csv_input = csv.DictReader(stream)
            for row in csv_input:
                employee = Employee(
                    session_id=session_obj.id,
                    name=row.get('Employee Name'),
                    level=row.get('Employee Level'),
                    calibration_rating=row.get('Calibration rating'),
                    promotion_offered=row.get('Promotion Offered')
                )
                db.session.add(employee)
            db.session.commit()
        elif file.filename.endswith('.xlsx'):
            df = pd.read_excel(file)
            for index, row in df.iterrows():
                employee = Employee(
                    session_id=session_obj.id,
                    name=row['Employee Name'],
                    level=row['Employee Level'],
                    calibration_rating=row['Calibration rating'],
                    promotion_offered=row['Promotion Offered']
                )
                db.session.add(employee)
            db.session.commit()
        else:
            flash('Unsupported file format', 'danger')
            return redirect(request.url)
        flash('Employees uploaded successfully!', 'success')
        return redirect(url_for('manage_session', session_id=session_id))
    return render_template('upload_employees.html', session=session_obj)

@app.route('/admin/session/<int:session_id>/start')
def start_session(session_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    session_obj.status = 'active'
    db.session.commit()
    flash('Session started and now active!', 'success')
    return redirect(url_for('manage_session', session_id=session_id))

@app.route('/admin/session/<int:session_id>/end')
def end_session(session_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    session_obj.status = 'closed'
    db.session.commit()
    flash('Session ended!', 'success')
    return redirect(url_for('manage_session', session_id=session_id))

@app.route('/admin/session/<int:session_id>/export')
def export_session(session_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Employee Name', 'Employee Level', 'Calibration rating', 'Promotion Offered'])
    for emp in session_obj.employees:
        writer.writerow([emp.name, emp.level, emp.calibration_rating, emp.promotion_offered])
    output.seek(0)
    return send_file(io.BytesIO(output.getvalue().encode('utf-8')),
                     mimetype='text/csv',
                     as_attachment=True,
                     download_name=f'session_{session_id}_export.csv')

# ---------------------------
# Contributor Routes
# ---------------------------
@app.route('/session/<int:session_id>/register', methods=['GET', 'POST'])
def register_contributor(session_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    if request.method == 'POST':
        first_name = request.form.get('first_name')
        last_name = request.form.get('last_name')
        contributor = Contributor(session_id=session_obj.id, first_name=first_name, last_name=last_name)
        db.session.add(contributor)
        db.session.commit()
        return redirect(url_for('calibration_session', session_id=session_id, contributor_id=contributor.id))
    return render_template('register_contributor.html', session=session_obj)

@app.route('/session/<int:session_id>/contributor/<int:contributor_id>', methods=['GET'])
def calibration_session(session_id, contributor_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    contributor = Contributor.query.get_or_404(contributor_id)
    levels = {}
    for emp in session_obj.employees:
        levels.setdefault(emp.level, []).append(emp)
    vote_data = {}
    for emp in session_obj.employees:
        cal_votes = db.session.query(Vote.calibration_action, func.count(Vote.id)).filter(Vote.employee_id == emp.id).group_by(Vote.calibration_action).all()
        promo_votes = db.session.query(Vote.promotion_action, func.count(Vote.id)).filter(Vote.employee_id == emp.id).group_by(Vote.promotion_action).all()
        vote_data[emp.id] = {
            'calibration': dict(cal_votes),
            'promotion': dict(promo_votes)
        }
    return render_template('calibration_session.html', session=session_obj, contributor=contributor, levels=levels, vote_data=vote_data)

# API endpoint for AJAX vote submission
@app.route('/api/session/<int:session_id>/contributor/<int:contributor_id>/vote', methods=['POST'])
def submit_votes(session_id, contributor_id):
    session_obj = CalibrationSession.query.get_or_404(session_id)
    contributor = Contributor.query.get_or_404(contributor_id)
    data = request.get_json()
    for emp_id, votes in data.items():
        cal_action = votes.get('calibration')
        promo_action = votes.get('promotion')
        if cal_action and promo_action:
            vote = Vote.query.filter_by(contributor_id=contributor.id, employee_id=emp_id).first()
            if not vote:
                vote = Vote(contributor_id=contributor.id, employee_id=emp_id,
                            calibration_action=cal_action, promotion_action=promo_action)
                db.session.add(vote)
            else:
                vote.calibration_action = cal_action
                vote.promotion_action = promo_action
    db.session.commit()
    return jsonify({"status": "success", "message": "Votes recorded"})

if __name__ == '__main__':
    app.run(debug=True)
