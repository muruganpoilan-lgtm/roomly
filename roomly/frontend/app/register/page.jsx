"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth, safeNext } from "../../components/AuthProvider";
import { api } from "../../lib/api";

export default function RegisterPage() {
  const router = useRouter();
  const { login } = useAuth();
  const [form, setForm] = useState({ name: "", email: "", phone: "", password: "" });
  const [owner, setOwner] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const set = (key) => (e) => setForm({ ...form, [key]: e.target.value });

  async function onSubmit(e) {
    e.preventDefault();
    setError("");
    if (!form.name.trim() || !form.email.trim()) {
      setError("Enter your name and email.");
      return;
    }
    if (form.password.length < 8) {
      setError("Your password needs at least 8 characters.");
      return;
    }
    setBusy(true);
    const res = await api("/auth/register", {
      method: "POST",
      body: {
        name: form.name.trim(),
        email: form.email.trim(),
        phone: form.phone.trim() || null,
        password: form.password,
        role: owner ? "owner" : "guest",
      },
    });
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    login(res.data.token, res.data.role);
    const next = new URLSearchParams(window.location.search).get("next");
    router.push(safeNext(next, owner ? "/dashboard" : "/"));
  }

  return (
    <main className="page auth">
      <h1>Create your account</h1>
      <form className="stack" onSubmit={onSubmit} noValidate>
        <label className="field">
          <span>Full name</span>
          <input type="text" value={form.name} onChange={set("name")} autoComplete="name" />
        </label>
        <label className="field">
          <span>Email</span>
          <input type="email" value={form.email} onChange={set("email")} autoComplete="email" />
        </label>
        <label className="field">
          <span>Mobile number (optional)</span>
          <input type="tel" value={form.phone} onChange={set("phone")} autoComplete="tel" />
        </label>
        <label className="field">
          <span>Password</span>
          <input type="password" value={form.password} onChange={set("password")} autoComplete="new-password" />
        </label>
        <label className="check">
          <input type="checkbox" checked={owner} onChange={(e) => setOwner(e.target.checked)} />
          <span>I want to list my property on Roomly</span>
        </label>
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <button type="submit" className="btn btn-primary" aria-busy={busy}>
          {busy ? "Creating your account…" : "Create account"}
        </button>
      </form>
      <p className="auth-alt">
        Already have an account? <Link href="/login">Log in</Link>
      </p>
    </main>
  );
}
