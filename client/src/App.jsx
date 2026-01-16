import React, { useEffect, useState } from "react"
import TaskList from "./components/TaskList"
import TaskForm from "./components/TaskForm"

const API = import.meta.env.VITE_API_URL || "http://localhost:8080"

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
