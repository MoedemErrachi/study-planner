# Creates a Study Planner project under C:\Users\errac\Desktop\cloud_proj
$base = 'C:\Users\errac\Desktop\cloud_proj'
New-Item -ItemType Directory -Path $base -Force | Out-Null

# Create server
$server = Join-Path $base 'server'
New-Item -ItemType Directory -Path $server -Force | Out-Null
@'
{
  "name": "study-planner-server",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.0.0",
    "express": "^4.18.2",
    "mysql2": "^3.2.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.22"
  }
}
'@ | Out-File -Encoding UTF8 (Join-Path $server 'package.json')

@'
PORT=4000
DB_HOST=your-rds-host.rds.amazonaws.com
DB_PORT=3306
DB_USER=youruser
DB_PASSWORD=yourpassword
DB_NAME=study_planner

# Optional: set CORS_ORIGIN to the frontend URL (e.g., http://localhost:5173)
CORS_ORIGIN=
'@ | Out-File -Encoding UTF8 (Join-Path $server '.env.example')

@'
const mysql = require('mysql2/promise');
const dotenv = require('dotenv');

dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT) : 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'study_planner',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

module.exports = pool;
'@ | Out-File -Encoding UTF8 (Join-Path $server 'db.js')

@'
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const pool = require('./db');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 4000;

app.use(express.json());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));

app.get('/tasks', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM tasks ORDER BY due_date IS NULL, due_date, created_at');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

app.post('/tasks', async (req, res) => {
  try {
    const { title, notes, due_date } = req.body;
    const [result] = await pool.query('INSERT INTO tasks (title, notes, due_date) VALUES (?, ?, ?)', [title, notes || null, due_date || null]);
    const [rows] = await pool.query('SELECT * FROM tasks WHERE id = ?', [result.insertId]);
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

app.put('/tasks/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const { title, notes, due_date, completed } = req.body;
    await pool.query('UPDATE tasks SET title = ?, notes = ?, due_date = ?, completed = ? WHERE id = ?', [title, notes || null, due_date || null, !!completed, id]);
    const [rows] = await pool.query('SELECT * FROM tasks WHERE id = ?', [id]);
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

app.delete('/tasks/:id', async (req, res) => {
  try {
    const id = req.params.id;
    await pool.query('DELETE FROM tasks WHERE id = ?', [id]);
    res.status(204).end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

app.listen(PORT, () => {
  console.log(`Study planner API listening on port ${PORT}`);
});
'@ | Out-File -Encoding UTF8 (Join-Path $server 'index.js')

New-Item -ItemType Directory -Path (Join-Path $server 'migrations') -Force | Out-Null
@'
CREATE DATABASE IF NOT EXISTS study_planner;
USE study_planner;

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  notes TEXT,
  due_date DATE,
  completed TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
'@ | Out-File -Encoding UTF8 (Join-Path $server 'migrations\init.sql')

# Create client
$client = Join-Path $base 'client'
New-Item -ItemType Directory -Path $client -Force | Out-Null
@'
{
  "name": "study-planner-client",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^5.0.0"
  }
}
'@ | Out-File -Encoding UTF8 (Join-Path $client 'package.json')

@'
import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"

export default defineConfig({
  plugins: [react()],
  server: { port: 5173 }
})
'@ | Out-File -Encoding UTF8 (Join-Path $client 'vite.config.js')

@'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Study Planner</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@ | Out-File -Encoding UTF8 (Join-Path $client 'index.html')

New-Item -ItemType Directory -Path (Join-Path $client 'src') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $client 'src\components') -Force | Out-Null

@'
import React from "react"
import { createRoot } from "react-dom/client"
import App from "./App"
import "./styles.css"

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
'@ | Out-File -Encoding UTF8 (Join-Path $client 'src\main.jsx')

@'
import React, { useEffect, useState } from "react"
import TaskList from "./components/TaskList"
import TaskForm from "./components/TaskForm"

const API = import.meta.env.VITE_API_URL || "http://localhost:4000"

export default function App() {
  const [tasks, setTasks] = useState([])

  const fetchTasks = async () => {
    const res = await fetch(`${API}/tasks`)
    const data = await res.json()
    setTasks(data)
  }

  useEffect(() => { fetchTasks() }, [])

  return (
    <div className="app">
      <header>
        <h1>Study Planner</h1>
      </header>
      <main>
        <TaskForm onCreated={fetchTasks} api={API} />
        <TaskList tasks={tasks} setTasks={setTasks} api={API} />
      </main>
    </div>
  )
}
'@ | Out-File -Encoding UTF8 (Join-Path $client 'src\App.jsx')

@'
import React from "react"

export default function TaskList({ tasks, setTasks, api }) {
  const toggle = async (task) => {
    await fetch(`${api}/tasks/${task.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...task, completed: !task.completed })
    })
    const res = await fetch(`${api}/tasks`)
    setTasks(await res.json())
  }

  const remove = async (id) => {
    if (-not (Read-Host -Prompt "Confirm delete? (type yes to confirm)" ) -eq "yes") { return }
    await fetch(`${api}/tasks/${id}`, { method: "DELETE" })
    setTasks(tasks.filter(t => t.id -ne id))
  }

  const edit = async (task) => {
    $title = Read-Host -Prompt "Edit title (leave blank to cancel)"
    if ($title -eq "") { return }
    await fetch(`${api}/tasks/${task.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...task, title: $title })
    })
    const res = await fetch(`${api}/tasks`)
    setTasks(await res.json())
  }

  return (
    <section className="task-list">
      {tasks.length === 0 && <p className="muted">No tasks yet — add one!</p>}
      {tasks.map(task => (
        <div key={task.id} className={`task ${task.completed ? "done" : ""}`}>
          <div className="left">
            <input type="checkbox" checked={!!task.completed} onChange={() => toggle(task)} />
            <div className="meta">
              <div className="title">{task.title}</div>
              {task.notes && <div className="notes">{task.notes}</div>}
            </div>
          </div>
          <div className="right">
            {task.due_date && <div className="due">Due: {task.due_date}</div>}
            <button onClick={() => edit(task)}>Edit</button>
            <button className="danger" onClick={() => remove(task.id)}>Delete</button>
          </div>
        </div>
      ))}
    </section>
  )
}
'@ | Out-File -Encoding UTF8 (Join-Path $client 'src\components\TaskList.jsx')

@'
import React, { useState } from "react"

export default function TaskForm({ onCreated, api }) {
  const [title, setTitle] = useState("")
  const [notes, setNotes] = useState("")
  const [due, setDue] = useState("")

  const submit = async (e) => {
    e.preventDefault()
    if (!title.trim()) { alert("Title required"); return }
    await fetch(`${api}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: title.trim(), notes: notes.trim() || null, due_date: due || null })
    })
    setTitle("")
    setNotes("")
    setDue("")
    onCreated()
  }

  return (
    <form className="task-form" onSubmit={submit}>
      <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Task title" />
      <input value={due} onChange={e => setDue(e.target.value)} type="date" />
      <input value={notes} onChange={e => setNotes(e.target.value)} placeholder="Notes (optional)" />
      <button type="submit">Add Task</button>
    </form>
  )
}
'@ | Out-File -Encoding UTF8 (Join-Path $client 'src\components\TaskForm.jsx')

@'
:root{
  --bg:#0f1724; --card:#0b1220; --accent:#60a5fa; --muted:#9ca3af; --danger:#ef4444; --glass: rgba(255,255,255,0.03);
}
*{box-sizing:border-box}
html,body,#root{height:100%}
body{margin:0;font-family:Inter,Segoe UI,Roboto,Arial;background:linear-gradient(180deg,#071126 0%, #081826 100%);color:#e6eef8}
.app{max-width:900px;margin:36px auto;padding:20px}
header{display:flex;align-items:center;gap:16px}
header h1{margin:0;font-size:28px;color:var(--accent)}
main{margin-top:18px;background:var(--card);padding:18px;border-radius:12px;box-shadow:0 8px 30px rgba(2,6,23,0.6)}
.task-form{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.task-form input{flex:1 1 200px;padding:10px;border-radius:8px;border:1px solid rgba(255,255,255,0.06);background:var(--glass);color:inherit}
.task-form button{padding:10px 14px;border-radius:8px;border:none;background:var(--accent);color:#04243b;font-weight:600}
.task-list{display:flex;flex-direction:column;gap:10px}
.task{display:flex;justify-content:space-between;align-items:center;padding:12px;border-radius:10px;background:linear-gradient(180deg, rgba(255,255,255,0.02), rgba(255,255,255,0.01));border:1px solid rgba(255,255,255,0.02)}
.task .left{display:flex;align-items:flex-start;gap:10px}
.task input[type="checkbox"]{width:18px;height:18px}
.task .meta{display:flex;flex-direction:column}
.task .title{font-weight:600}
.task .notes{font-size:13px;color:var(--muted)}
.task .right{display:flex;align-items:center;gap:8px}
.task .due{font-size:13px;color:var(--muted)}
.task button{padding:8px 10px;border-radius:8px;border:1px solid rgba(255,255,255,0.04);background:transparent;color:inherit}
.task button.danger{border-color:rgba(239,68,68,0.2);color:var(--danger)}
.task.done .title{text-decoration:line-through;color:var(--muted)}
.muted{color:var(--muted)}
'@ | Out-File -Encoding UTF8 (Join-Path $client 'src\styles.css')

Write-Host 'Project scaffold created at:' $base
