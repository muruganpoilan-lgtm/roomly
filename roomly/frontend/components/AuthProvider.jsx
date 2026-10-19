"use client";

import { createContext, useCallback, useContext, useEffect, useState } from "react";

const AuthContext = createContext({ ready: false, token: null, role: null, login() {}, logout() {} });

const TOKEN_KEY = "roomly_token";
const ROLE_KEY = "roomly_role";

// The token lives in this browser's localStorage. Fine for development; before launch,
// move it to an httpOnly cookie set by the server so scripts can't read it.
export function AuthProvider({ children }) {
  const [state, setState] = useState({ ready: false, token: null, role: null });

  useEffect(() => {
    let token = null;
    let role = null;
    try {
      token = localStorage.getItem(TOKEN_KEY);
      role = localStorage.getItem(ROLE_KEY);
    } catch {}
    setState({ ready: true, token, role });
  }, []);

  const login = useCallback((token, role) => {
    try {
      localStorage.setItem(TOKEN_KEY, token);
      localStorage.setItem(ROLE_KEY, role);
    } catch {}
    setState({ ready: true, token, role });
  }, []);

  const logout = useCallback(() => {
    try {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(ROLE_KEY);
    } catch {}
    setState({ ready: true, token: null, role: null });
  }, []);

  return <AuthContext.Provider value={{ ...state, login, logout }}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);

// Only follow redirects that stay on this site.
export function safeNext(value, fallback = "/") {
  if (typeof value === "string" && value.startsWith("/") && !value.startsWith("//")) return value;
  return fallback;
}
