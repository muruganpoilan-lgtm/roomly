"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "../../../components/AuthProvider";
import Guard from "../../../components/dashboard/Guard";
import PropertyForm from "../../../components/dashboard/PropertyForm";
import { api } from "../../../lib/api";

function NewProperty() {
  const router = useRouter();
  const { token, logout } = useAuth();

  async function create(body) {
    const res = await api("/owner/properties", { method: "POST", token, body });
    if (res.status === 401) {
      logout();
      return "Your session ended. Log in again.";
    }
    if (!res.ok) return res.error;
    router.push(`/dashboard/properties/${res.data.id}?created=1`);
    return null;
  }

  return (
    <>
      <p className="meta">
        <Link href="/dashboard">← Your properties</Link>
      </p>
      <h1 className="section-title">Add a property</h1>
      <p className="meta form-intro">Start with the basics. You'll add rooms, photos and open dates on the next screen.</p>
      <div className="narrow">
        <PropertyForm submitLabel="Save and continue" onSubmit={create} />
      </div>
    </>
  );
}

export default function NewPropertyPage() {
  return (
    <Guard>
      <NewProperty />
    </Guard>
  );
}
