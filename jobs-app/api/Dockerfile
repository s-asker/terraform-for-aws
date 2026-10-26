FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py validation.py ./
ENV PYTHONUNBUFFERED=1 PORT=8080
USER 10001:10001
EXPOSE 8080
CMD ["python", "app.py"]
