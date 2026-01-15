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
