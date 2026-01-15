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
    if (!confirm('Delete this task?')) return
    await fetch(`${api}/tasks/${id}`, { method: 'DELETE' })
    setTasks(tasks.filter(t => t.id !== id))
  }

  const edit = async (task) => {
    const title = prompt('Edit title', task.title)
    if (title == null) return
    await fetch(`${api}/tasks/${task.id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...task, title })
    })
    const res = await fetch(`${api}/tasks`)
    setTasks(await res.json())
  }

  return (
    <section className="task-list">
      {tasks.length === 0 && <p className="muted">No tasks yet — add one!</p>}
      {tasks.map(task => (
        <div key={task.id} className={`task ${task.completed ? 'done' : ''}`}>
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
