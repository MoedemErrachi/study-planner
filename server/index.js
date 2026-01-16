const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const pool = require('./db');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8080;

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
  console.log('Study planner API listening on port ' + PORT);
});

// Health check endpoint (required by ALB)
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      database: 'connected'
    });
  } catch (error) {
    res.status(503).json({ 
      status: 'unhealthy', 
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error.message
    });
  }
});