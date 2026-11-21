FROM python:3.13-slim
WORKDIR /app
COPY radio.py .
USER 65534:65534
CMD ["python", "radio.py", "--bind", "0.0.0.0"]
