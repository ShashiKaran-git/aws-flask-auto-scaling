from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return {
        "message": "Hello Karan, Im from the Kubernetes!",
        "status": "healthy"
    }

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)# trigger pipeline
# retry pipeline
# docker fix
# CD test
# test versioning
# triggering helm deployment
