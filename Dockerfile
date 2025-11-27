# Stage 1: Define the base operating system and runtime environment
# Use a lightweight base image suitable for your application.
# Example for Python:
FROM python:3.11-slim

# Set working directory inside the container
WORKDIR /app

# Optional: Install Git if it's not included in the base image (it often is in -slim images)
# For Debian/Ubuntu-based images:
RUN apt-get update && apt-get install -y git \
    && rm -rf /var/lib/apt/lists/*

# Clone the GitHub repository directly into the /app directory.
# Replace <YOUR_GITHUB_ORG> and <YOUR_REPO_NAME> with your actual details.
# NOTE: This uses the public HTTP URL. If your repo is private, see the security note below.
RUN git clone -b docker_testing https://${GITHUB_TOKEN}@github.com/hhelleboid/Projet_Cloud_M2.git .

# Check the files in the repo    
RUN ls -l

# Install dependencies from the cloned repository.
# This assumes your dependencies are listed in a requirements.txt file at the root.
RUN pip install --no-cache-dir -r app/requirements.txt

RUN python app/chunking.py

# Expose the port your application listens on (e.g., 8000 for Flask/Django, 3000 for Node)
EXPOSE 8000

# Set the command to run the application when the container starts.
# Replace 'app.py' and '--host 0.0.0.0' with your application's specific startup command.
# CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "8000"]
CMD ["streamlit", "run", "app/query.py", "--server.port", "8000", "--server.address", "0.0.0.0"]