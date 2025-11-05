# ENMS Demo - Energy & Network Management System# **ENMS Project** – IoT-based Energy & Device Monitoring System



[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)## 📌 Overview

[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](docker-compose.yml)

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python)](python-api/)The **ENMS Project** is an **IoT-based, real-time monitoring and analytics platform** designed for factories, production facilities, and IoT environments.

[![Node-RED](https://img.shields.io/badge/Node--RED-8F0000?logo=node-red)](node-red/)It integrates **Node-RED**, **PostgreSQL**, **Grafana**, **Python Flask API**, and **Nginx** into a **zero-touch Dockerized deployment**.



A comprehensive Industrial IoT demonstration system for real-time energy monitoring, machine learning predictions, and Digital Product Passport (DPP) generation for 3D printing operations.Main features:



## 🎯 Overview* Real-time IoT data ingestion (MQTT, Modbus, APIs).

* PostgreSQL (TimescaleDB) storage for time-series analysis.

ENMS Demo is an enterprise-grade Industrial IoT platform that showcases:* Grafana dashboards for rich visualization.

* Node-RED automation flows.

- **Real-time Energy Monitoring**: Track power consumption across 33 industrial 3D printers* Flask API for external integrations.

- **ML-Powered Anomaly Detection**: Predict equipment failures before they occur  * Web-based CRUD interface for easy device and credential management.

- **Digital Product Passports**: Auto-generate compliance reports with energy tracking* Fully containerized for easy deployment.

- **Interactive Dashboards**: Grafana visualizations with 29+ documented panels

- **MQTT Integration**: IoT device connectivity with live sensor data---

- **RESTful APIs**: Python FastAPI backend for data access

- **Time-Series Analytics**: TimescaleDB for efficient historical data queries## System Architecture



## 🏗️ Architecture![ENMS Architecture](docs/Systems%20Architecture%20v2.png)



```

┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐---

│   MQTT Broker   │────▶│    Node-RED      │────▶│  TimescaleDB    │

│  (Mosquitto)    │     │  IoT Processing  │     │  Time-Series    │## 🚀 Quick Start

└─────────────────┘     └──────────────────┘     └─────────────────┘

                               │                          │### 1️⃣ Clone the repository

                               ▼                          ▼

                        ┌──────────────┐         ┌──────────────┐```bash

                        │  Python API  │◀────────│   Grafana    │git clone https://gitlab.com/raptorblingx/enms-project.git

                        │  ML Worker   │         │  Dashboards  │cd enms-project

                        └──────────────┘         └──────────────┘```

                               │

                               ▼### 2️⃣ Create the environment file

                        ┌──────────────┐

                        │ Nginx Server │The project uses a `.env` file to manage essential variables like database credentials and secrets. Create it by copying the template:

                        │   Frontend   │

                        └──────────────┘```bash

```cp .env.example .env

```

## ✨ Key Features*This file contains default credentials. For any non-local or production use, you should update the `MQTT_PASSWORD` and `NODE_RED_CREDENTIAL_SECRET` with your own secure values.*



### 📊 Real-Time Monitoring### 3️⃣ Build & run the stack

- **33 Virtual 3D Printers**: Simulated industrial environment

- **Live Energy Tracking**: kWh consumption per device and facility-wide```bash

- **Motion Analytics**: Accelerometer data with RMS vibration analysisdocker compose up --build -d

- **Environmental Sensors**: Temperature, humidity tracking```

- **State Detection**: Idle, printing, heating, cooling, offline states

### 4️⃣ Access services

### 🤖 Machine Learning

- **Anomaly Detection**: LSTM neural network for predictive maintenance| Service    | URL                                                                   |

- **Feature Engineering**: 15+ engineered features from sensor data| ---------- | --------------------------------------------------------------------- |

- **Real-Time Inference**: Sub-second predictions on live data streams| Node-RED   | [http://localhost:1880](http://localhost:1880)                        |

- **Model Versioning**: Trained models stored in `/backend/models/`| Grafana    | [http://localhost:3000](http://localhost:3000)                        |

| Web Server | [http://localhost/](http://localhost/)                                |

### 📋 Digital Product Passports (DPP)| Flask API  | [http://localhost/api/dpp\_summary](http://localhost/api/dpp_summary) |

- **Auto-Generated Reports**: PDF reports for every completed print job| PostgreSQL | `localhost:5432` (user/pass in `.env`)                                |

- **Energy Consumption**: Detailed kWh tracking per job

- **Plant Growth Visualization**: Sustainability gamification with 4 plant types---

- **GCode Analysis**: Layer count, infill, dimensions, print time

- **Compliance Ready**: ISO 50001 energy management integration## ⚙ Environment Variables



### 📈 Grafana DashboardsAll user-configurable variables for the project are managed in a single `.env` file in the root of the repository. This file is not checked into source control and must be created locally.

Five professional dashboards with 29 documented panels:

1. **Fleet Operations** (6 panels): Overview of all printersTo get started, simply copy the provided template:

2. **Machine Performance** (3 panels): Individual printer deep-dive```bash

3. **Sensor Data Explorer** (10 panels): Raw sensor analyticscp .env.example .env

4. **Industrial Hybrid Edge** (6 panels): System health monitoring```

5. **ESP32 Motion Analysis** (4 panels): Vibration analysisThe `.env.example` file contains all the necessary variables with sensible default values for a local development environment.



## 🚀 Quick Start**Important:** The default passwords and secrets in the `.env.example` file are for convenience only. You should change `MQTT_PASSWORD` and `NODE_RED_CREDENTIAL_SECRET` to your own secure, randomly generated strings before running the project in any non-local or production setting.



### Prerequisites---

- Docker Engine 24.0+

- Docker Compose V2## 📦 Project Structure

- 8GB RAM minimum

- 20GB free disk space```

enms-project/

### Installation│

├── backend/             # Backend services, including database initialization and ML model training

1. **Clone the repository**├── docs/                # Supporting documentation and architecture diagrams

```bash├── frontend/            # Frontend HTML, CSS, and JavaScript files

git clone https://github.com/RaptorBlingx/enms-demo.git├── grafana/             # Grafana provisioning (datasources, dashboards)

cd enms-demo├── nginx/               # Nginx reverse proxy configuration

```├── node-red/            # Node-RED flows, settings, and custom nodes

├── python-api/          # Python Flask application for the DPP API

2. **Configure environment**├── artistic-resources/  # Image assets for the frontend

```bash├── docker-compose.yml   # Main Docker Compose file for orchestrating services

cp .env.example .env├── ANALYSIS_DEEP_DIVE.md # Deep dive into the analysis engine & ML models

# Edit .env with your configuration├── Custom Hardware.md # Details on custom sensor hardware (ESP32, etc.)

```├── DPP_API_Documentation.md # Detailed developer documentation for the DPP API

├── ui_guide.md          # Guide to the user interface and user profiles

3. **Start all services**├── ENMS_Technical_Details.md # General project documentation

```bash└── README.md            # This file

docker compose up -d```

```

---

4. **Start data generators**

```bash## 🧩 Included Services

python3 realtime_demo_generator.py &

python3 realtime_iot_generator.py &* **Nginx** – Reverse proxy and web server for the frontend application.

```* **Node-RED** – Low-code environment for data ingestion, processing, and automation flows.

* **PostgreSQL + TimescaleDB** – Optimized time-series database for storing sensor data.

### Access Points* **Grafana** – Rich, real-time dashboards for visualizing system and sensor data.

* **Python API** – A Flask-based API for generating reports and other backend tasks.

| Service | URL | Credentials |* **Mosquitto** – A lightweight MQTT broker for real-time messaging between services.

|---------|-----|-------------|* **ML Worker** – A Python service that runs machine learning models for predictive analytics.

| **Main Dashboard** | http://localhost:8090 | - |

| **Grafana** | http://localhost:3002 | admin / (see .env) |---

| **Node-RED** | http://localhost:1882 | (configured in settings) |

| **API Docs** | http://localhost:5000/docs | - |## 📄 Documentation

| **DPP Interface** | http://localhost:8090/dpp_page.html | - |

*   For **The DPP API Reference**, see: 📖 [`DPP_API_Documentation.md`](./DPP_API_Documentation.md)

## 📁 Project Structure*   For **Technical Details** (architecture, data flows, deployment), see: 📜 [`ENMS_Technical_Details.md`](./ENMS_Technical_Details.md)

*   For a **Guide to the User Interface** and different user profiles, see: 👤 [`ui_guide.md`](./ui_guide.md)

```*   For a **Deep Dive into the Analysis Engine and ML Model Training**, see: 🧠 [`ANALYSIS_DEEP_DIVE.md`](./ANALYSIS_DEEP_DIVE.md)

enms-demo/*   For a **Guide to the Interactive Analysis Feature**, see: 📊 [`INTERACTIVE_ANALYSIS_GUIDE.md`](./INTERACTIVE_ANALYSIS_GUIDE.md)

├── backend/*   For **Details on the Custom Sensor Hardware** and connectivity, see: 🔩 [`Custom Hardware.md`](./Custom%20Hardware.md)

│   ├── db_init/              # Database initialization scripts

│   ├── models/               # ML models (LSTM, Random Forest)---

│   └── Dockerfile

├── frontend/## 🛡 Zero-Touch Deployment

│   ├── index.html            # Main dashboard

│   ├── dpp_page.html         # Digital Product Passport viewerThis project supports **zero-touch deployment**:

│   ├── analysis/             # Analytics pages

│   └── components/           # Reusable UI components* All flows, settings, and dashboards are preloaded.

├── python-api/* No manual post-deployment configuration required.

│   ├── app.py                # FastAPI application* Ready to use immediately after `docker compose up`.

│   ├── pdf_service.py        # DPP PDF generation
│   ├── dpp_simulator.py      # Real-time data simulator
│   ├── auth_service.py       # Authentication endpoints
│   └── templates/            # Jinja2 templates for PDFs
├── node-red/
│   ├── flows.json            # Node-RED flow definitions
│   └── nodes/                # Custom nodes
├── grafana/
│   ├── dashboards/           # 5 JSON dashboard definitions
│   └── provisioning/         # Auto-provisioning config
├── nginx/
│   └── conf.d/               # Reverse proxy configuration
├── artistic-resources/
│   └── plants/               # Plant growth images (4 species, 60+ stages)
├── docker-compose.yml        # Service orchestration
├── realtime_demo_generator.py    # Printer simulation
└── realtime_iot_generator.py     # IoT sensor simulation
```

## 🔧 Configuration

### Environment Variables

Create `.env` file with:

```bash
# Database
POSTGRES_DB=reg_ml_demo
POSTGRES_USER=reg_ml_demo
POSTGRES_PASSWORD=your_secure_password
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# MQTT
MQTT_BROKER_HOST=mosquitto
MQTT_PORT=1883
MQTT_USERNAME=your_mqtt_user
MQTT_PASSWORD=your_mqtt_password

# Node-RED
NODE_RED_CREDENTIAL_SECRET=your_secret_key
```

### Printer Fleet Configuration

Edit device list in `realtime_demo_generator.py` to customize the simulated printer fleet.

## 📊 Database Schema

### Core Tables
- `devices` - Printer/sensor registry (33 devices)
- `printer_status` - Real-time printer states (5s intervals)
- `energy_data` - Power consumption logs (hypertable)
- `print_jobs` - Completed job records with DPP data
- `ml_predictions` - Anomaly detection results
- `sensor_data` - Raw IoT sensor readings (hypertable)

## 📖 API Documentation

### REST Endpoints

#### Devices
```bash
GET  /api/devices              # List all devices
GET  /api/devices/{id}         # Get device details
GET  /api/devices/{id}/status  # Current status
```

#### Energy Data
```bash
GET  /api/energy/latest        # Latest readings
GET  /api/energy/timeseries    # Historical data
GET  /api/energy/summary       # Aggregated metrics
```

#### DPP (Digital Product Passport)
```bash
GET  /api/dpp_summary          # All printer states
POST /api/generate_dpp_pdf     # Generate PDF report
```

### MQTT Topics
```
sensors/{device_id}/energy      # Power consumption
sensors/{device_id}/motion      # Accelerometer data
sensors/{device_id}/environment # Temp/humidity
printers/{device_id}/status     # Printer state
```

## 🌱 Sustainability Features

### Plant Growth Gamification
Energy consumption visualized as plant growth:
- **Generic Plant**: 21 growth stages (0-1.0 kWh cycle)
- **Corn**: 8 stages, fast growth
- **Sunflower**: 7 stages, medium growth  
- **Tomato**: 12 stages, detailed lifecycle

Encourages energy awareness through visual feedback.

### ISO 50001 Integration
- Energy baseline tracking
- Performance indicators (EnPIs)
- Continuous improvement workflows
- Compliance reporting

## 🔒 Security

- **Authentication**: JWT-based API authentication
- **MQTT ACLs**: Username/password with topic restrictions
- **Network Isolation**: Docker internal networks
- **Secrets Management**: Environment variables, never committed
- **TLS Support**: Ready for production certificate mounting

⚠️ **Default Configuration**: This demo uses default credentials. **MUST** change for production!

## 🧪 Development

### Running Locally
```bash
# Start services
docker compose up -d

# Check logs
docker compose logs -f

# Stop services
docker compose down
```

### Accessing Logs
```bash
# All services
docker compose logs -f

# Specific service
docker logs enms_demo_python_api --follow
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/RaptorBlingx/enms-demo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/RaptorBlingx/enms-demo/discussions)

## 🙏 Acknowledgments

- **TimescaleDB** - Time-series database foundation
- **Node-RED** - Visual IoT programming
- **Grafana** - Beautiful dashboards
- **FastAPI** - Modern Python API framework
- **WeasyPrint** - PDF generation engine

---

**Built with ❤️ for the Industrial IoT community**
