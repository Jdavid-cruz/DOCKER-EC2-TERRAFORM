import os
import json
import psycopg2
from werkzeug.utils import secure_filename
from flask import Flask, render_template, request, redirect, url_for, session, send_from_directory
from dotenv import load_dotenv
load_dotenv()



app = Flask(__name__)

app.secret_key = 'clave_super_segura_123'


# 
# Configuración de la base de datos desde el archivo .env
DB_HOST = os.getenv("DB_HOST")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = os.getenv("DB_PORT", "5432")  # Por defecto usa el puerto 5432 si no está definido



# 📌 Configuración de carpeta de subida
UPLOAD_FOLDER = os.path.join('static', 'uploads')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# 📌 Crear la carpeta de uploads si no existe
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# 📌 Conectar a la base de datos
def conectar_bd():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        client_encoding="utf8"
    )

# 📌 Función para verificar archivos permitidos
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if not os.path.exists(filepath):
        print(f"⚠️ Archivo no encontrado: {filepath}")  # 📌 DEBUG: Ver si Flask intenta servir un archivo inexistente
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


@app.route('/')
def index():
    return render_template('index.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        phone = request.form.get('phone')
        email = request.form.get('email')
        password = request.form.get('password')

        if not username or not phone or not email or not password:
            return "❌ Error: Todos los campos son obligatorios", 400

        conn = conectar_bd()
        cursor = conn.cursor()
        sql = "INSERT INTO users (username, phone, email, password_hash) VALUES (%s, %s, %s, %s)"
        cursor.execute(sql, (username, phone, email, password))
        conn.commit()
        cursor.close()
        conn.close()

        session['email'] = email
        return redirect(url_for('home_usuario'))

    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')

        if not email or not password:
            return "❌ Error: Todos los campos son obligatorios", 400

        conn = conectar_bd()
        cursor = conn.cursor()
        cursor.execute("SELECT username FROM users WHERE email = %s AND password_hash = %s", (email, password))
        user = cursor.fetchone()
        cursor.close()
        conn.close()

        if user:
            session['email'] = email
            return redirect(url_for('home_usuario'))
        else:
            return "❌ Credenciales incorrectas"

    return render_template('login.html')

@app.route('/home_usuario', defaults={'username': None})
@app.route('/home_usuario/<string:username>')
def home_usuario(username):
    # Si no se especifica un username en la URL, se asume que se quiere ver el perfil propio
    if username is None:
        if 'email' not in session:
            return redirect(url_for('login'))
        
        email = session['email']
        conn = conectar_bd()
        cursor = conn.cursor()
        cursor.execute("SELECT username, phone, email FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()

        if user:
            return render_template('home_usuario.html', username=user[0], phone=user[1], email=user[2])
        else:
            return "Usuario no encontrado", 404
    else:
        # Se busca el perfil de otro usuario según el username pasado en la URL
        conn = conectar_bd()
        cursor = conn.cursor()
        cursor.execute("SELECT username, phone, email FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()

        if user:
            return render_template('home_usuario.html', username=user[0], phone=user[1], email=user[2])
        else:
            return "Usuario no encontrado", 404


@app.route('/publicar', methods=['POST'])
def publicar():
    if 'email' not in session:
        return redirect(url_for('login'))
    
    email = session['email']
    conn = conectar_bd()
    cursor = conn.cursor()
    cursor.execute("SELECT username FROM users WHERE email = %s", (email,))
    user = cursor.fetchone()

    if not user:
        cursor.close()
        conn.close()
        return "Usuario no encontrado", 404

    username = user[0]
    comment = request.form.get('comment', '').strip()

    if not comment or len(comment) > 100:
        cursor.close()
        conn.close()
        return "El comentario es obligatorio y debe tener máximo 100 caracteres", 400

    # 📌 Verificar si hay archivos en la solicitud
    print(f"🔍 Archivos en request.files: {request.files}")

    media_files = []
    if 'media_files' in request.files:
        files = request.files.getlist('media_files')
        print(f"🔍 Archivos recibidos: {files}")  # 📌 Imprimir lista de archivos

        for file in files:
            if file and allowed_file(file.filename):
                filename = secure_filename(file.filename)
                filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                print(f"📂 Guardando archivo en: {filepath}")  # 📌 Imprimir la ruta
                file.save(filepath)
                media_files.append(url_for('uploaded_file', filename=filename))

    print(f"📌 Archivos guardados en la base de datos: {media_files}")  # 📌 Depuración

    sql = "INSERT INTO publicaciones (username, comment, media_files) VALUES (%s, %s, %s)"
    cursor.execute(sql, (username, comment, json.dumps(media_files) if media_files else "[]"))
    conn.commit()
    cursor.close()
    conn.close()

    return redirect(url_for('principal'))



from flask import request

@app.route('/principal')
def principal():
    per_page = 15  # Número de publicaciones por página
    page = request.args.get('page', 1, type=int)  # Obtener el número de página desde la URL, por defecto es 1
    offset = (page - 1) * per_page  # Calcular el desplazamiento

    conn = conectar_bd()
    cursor = conn.cursor()

    # Obtener el número total de publicaciones
    cursor.execute("SELECT COUNT(*) FROM publicaciones")
    total_publicaciones = cursor.fetchone()[0]

    # Calcular el número total de páginas
    total_pages = (total_publicaciones + per_page - 1) // per_page  # Redondeo hacia arriba

    # Obtener las publicaciones paginadas
    cursor.execute("SELECT username, comment, media_files, created_at FROM publicaciones ORDER BY created_at DESC LIMIT %s OFFSET %s", (per_page, offset))
    publicaciones = cursor.fetchall()
    cursor.close()
    conn.close()

    publicaciones_lista = []
    for pub in publicaciones:
        username, comment, media_files, created_at = pub
        if isinstance(media_files, str):
            try:
                media_files = json.loads(media_files)  # 📌 Convertimos JSON a lista
            except json.JSONDecodeError:
                media_files = []
        elif media_files is None:
            media_files = []

        publicaciones_lista.append((username, comment, media_files, created_at))

    return render_template('principal.html', publicaciones=publicaciones_lista, page=page, total_pages=total_pages)


# 📌 Corregir conversión de JSON en la plantilla
@app.template_filter('fromjson')
def fromjson_filter(value):
    if isinstance(value, str):  # 📌 Solo convertir si es una cadena
        return json.loads(value)
    return value  # Si ya es una lista, devolverla tal cual

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)

