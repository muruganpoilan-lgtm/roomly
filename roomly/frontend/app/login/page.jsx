"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth, safeNext } from "../../components/AuthProvider";
import { api } from "../../lib/api";

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(e) {
    e.preventDefault();
    setError("");
    if (!email.trim() || !password) {
      setError("Enter your email and password.");
      return;
    }
    setBusy(true);
    const res = await api("/auth/login", { method: "POST", body: { email: email.trim(), password } });
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    login(res.data.token, res.data.role);
    const next = new URLSearchParams(window.location.search).get("next");
    router.push(safeNext(next, "/"));
  }

  return (
    <main className="page auth">
      <h1>Log in</h1>
      <form className="stack" onSubmit={onSubmit} noValidate>
        <label className="field">
          <span>Email</span>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" />
        </label>
        <label className="field">
          <span>Password</span>
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" />
        </label>
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <button type="submit" className="btn btn-primary" aria-busy={busy}>
          {busy ? "Logging in…" : "Log in"}
        </button>
      </form>
      <p className="auth-alt">
        New here? <Link href="/register">Create an account</Link>
      </p>
    </main>
  );
}
