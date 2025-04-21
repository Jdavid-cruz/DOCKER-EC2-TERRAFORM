# 1. Usamos una imagen base ligera de Python 3.10
FROM python:3.10-slim

# 2. Creamos y nos movemos al directorio de trabajo dentro del contenedor
WORKDIR /app

# 3. Copiamos todos los archivos del proyecto (HTML, CSS, app.py, etc.) al contenedor
COPY . .

# 4. Instalamos las dependencias de Python desde requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# 5. Exponemos el puerto 5000 (por donde corre Flask)
EXPOSE 5000

# 6. Comando para ejecutar la aplicación Flask al arrancar el contenedor
CMD ["python", "app.py"]
