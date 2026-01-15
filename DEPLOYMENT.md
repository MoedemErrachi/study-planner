# Deployment Guide: EC2 + RDS

This guide walks you through deploying the Study Planner to AWS using:
- **RDS** (MySQL 8.0) for the database
- **EC2** (Amazon Linux 2 or Ubuntu) for the Node.js backend
- **S3 + CloudFront** or **EC2** for the React frontend

---

## 1. Set Up RDS (MySQL Database)

### Create RDS Instance

1. Open **AWS Management Console** → **RDS** → **Create Database**
2. Engine: **MySQL 8.0** (or latest 8.x)
3. DB Instance Class: **db.t3.micro** (free tier eligible)
4. Storage: **20 GB** (free tier eligible)
5. DB Instance Identifier: `study-planner-db`
6. Master Username: `admin`
7. Master Password: Save this securely
8. Publicly Accessible: **Yes** (for now; restrict later)
9. VPC: Use default or your custom VPC
10. Security Group: Create a new one called `study-planner-db-sg`
11. Initial Database Name: `study_planner`
12. Click **Create Database** (takes ~5 min)

### Get RDS Endpoint

After the instance is created, note the **Endpoint** (e.g., `study-planner-db.xxxxx.us-east-1.rds.amazonaws.com`).

### Add Inbound Rule to RDS Security Group

1. Go to RDS → Databases → `study-planner-db` → **VPC security groups**
2. Click the security group name
3. **Inbound rules** → **Edit**
4. Add rule:
   - Type: **MySQL/Aurora**
   - Port: **3306**
   - Source: **Your IP** (or later: the EC2 instance security group)
5. Save

### Run Migration

From your local machine (with mysql-client installed):

```bash
mysql -h <RDS_ENDPOINT> -u admin -p < server/migrations/init.sql
# Enter password when prompted
```

Verify:
```bash
mysql -h <RDS_ENDPOINT> -u admin -p -e "SELECT * FROM study_planner.tasks;"
```

---

## 2. Set Up EC2 (Node.js Backend)

### Launch EC2 Instance

1. Open **AWS EC2 Dashboard** → **Launch Instances**
2. AMI: **Amazon Linux 2** (or Ubuntu 20.04+)
3. Instance Type: **t2.micro** (free tier eligible)
4. Security Group: Create new `study-planner-app-sg`
   - Inbound: **SSH (22)** from your IP
   - Inbound: **HTTP (80)** from **0.0.0.0/0** (for health checks)
   - Inbound: **Custom TCP 4000** from **0.0.0.0/0** (API port)
5. Key Pair: Create new, download `.pem` file
6. Click **Launch**

### Connect to EC2

```bash
# On your local machine
chmod 600 /path/to/your-key.pem
ssh -i /path/to/your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

### Install Node.js & Git

```bash
# Amazon Linux 2
sudo yum update -y
sudo yum install -y nodejs npm git

# Verify
node --version
npm --version
```

### Deploy Backend

```bash
# Clone or copy your project
git clone <your-repo-url> study-planner
cd study-planner/server

# Install dependencies
npm install --production

# Create .env with RDS credentials
cat > .env << EOF
PORT=4000
DB_HOST=<RDS_ENDPOINT>
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=<YOUR_RDS_PASSWORD>
DB_NAME=study_planner
CORS_ORIGIN=http://<FRONTEND_URL>
EOF

# Test server
node index.js
```

You should see: `Study planner API listening on port 4000`

### Run Server as Service (PM2)

For production, use **PM2** to keep the server running:

```bash
cd ~/study-planner/server
sudo npm install -g pm2

# Start app with PM2
pm2 start index.js --name "study-planner-api"
pm2 startup
pm2 save

# Check status
pm2 status
```

To view logs:
```bash
pm2 logs study-planner-api
```

### Configure Firewall (if using UFW on Ubuntu)

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 4000/tcp
sudo ufw enable
```

---

## 3. Deploy Frontend

### Option A: On Same EC2 (Simple)

```bash
cd ~/study-planner/client

# Install dependencies
npm install

# Build for production
npm run build
# Creates dist/ folder

# Serve with Node/Express
npm install -g serve
serve -s dist -l 3000
```

Then update EC2 security group to allow port 3000.

### Option B: S3 + CloudFront (Recommended for Scale)

```bash
# Build locally
cd client
npm run build

# Upload to S3
aws s3 sync dist/ s3://your-study-planner-bucket/ --delete

# CloudFront will cache and serve globally
```

---

## 4. Update Frontend API URL

When deployed, update the frontend API endpoint. In `client/src/App.jsx`:

```javascript
const API = import.meta.env.VITE_API_URL || "https://<EC2_PUBLIC_IP>:4000"
```

Or set environment variable when building:
```bash
VITE_API_URL="https://api.yourdomain.com" npm run build
```

---

## 5. Security Checklist

- [ ] RDS: Restrict DB security group to only EC2 security group (not 0.0.0.0)
- [ ] EC2: Use SSH key-pair (never password login)
- [ ] Enable **VPC Flow Logs** for monitoring
- [ ] Set up **CloudWatch Alarms** for CPU/memory
- [ ] Use **Systems Manager Session Manager** instead of SSH (more secure)
- [ ] Enable **RDS automated backups** (7-day retention minimum)
- [ ] Use **Secrets Manager** for sensitive credentials (instead of .env)
- [ ] Enable **HTTPS** with **ACM** (AWS Certificate Manager)

---

## 6. Monitoring & Logging

### CloudWatch Logs

```bash
# View EC2 application logs
pm2 logs study-planner-api

# Ship to CloudWatch
pm2 install pm2-logrotate
```

### RDS Performance Insights

Open RDS Console → Performance Insights to track queries and performance.

---

## Cost Estimate (Monthly, US East)

| Service | Instance | Cost |
|---------|----------|------|
| RDS | db.t3.micro | ~$15 |
| EC2 | t2.micro | ~$11 (on-demand) |
| Data Transfer | ~100 GB | ~$9 |
| **Total** | | ~**$35** (free tier eligible) |

---

## Next Steps

1. Provision RDS and run migration
2. Launch EC2 instance and deploy backend
3. Test API: `curl https://<EC2_IP>:4000/tasks`
4. Deploy frontend to S3 or EC2
5. Set up domain + HTTPS with Route 53 + ACM
6. Configure auto-scaling and load balancing for production

For help, check AWS documentation or post issues to your project repo.
