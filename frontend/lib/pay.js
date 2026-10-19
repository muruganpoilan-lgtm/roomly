import { api } from "./api";

let scriptPromise = null;
function loadCheckout() {
  if (typeof window === "undefined") return Promise.reject(new Error("no window"));
  if (window.Razorpay) return Promise.resolve();
  if (!scriptPromise) {
    scriptPromise = new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = "https://checkout.razorpay.com/v1/checkout.js";
      s.onload = resolve;
      s.onerror = () => {
        scriptPromise = null;
        reject(new Error("load"));
      };
      document.body.appendChild(s);
    });
  }
  return scriptPromise;
}

// Opens Razorpay's payment window for a held booking.
// Resolves to {ok:true, data:{status:"confirmed"|"refunded"}}, {ok:false, dismissed:true} or {ok:false, error}.
export async function payForBooking({ bookingId, token, description }) {
  const order = await api(`/payments/bookings/${bookingId}/order`, { method: "POST", token });
  if (!order.ok) return order;
  try {
    await loadCheckout();
  } catch {
    return { ok: false, status: 0, error: "Couldn't load the payment window. Check your internet connection and try again." };
  }
  return new Promise((resolve) => {
    const rzp = new window.Razorpay({
      key: order.data.key_id,
      order_id: order.data.order_id,
      amount: order.data.amount,
      currency: order.data.currency,
      name: "Roomly",
      description,
      theme: { color: "#0e6b58" },
      // Razorpay hands back razorpay_order_id, razorpay_payment_id and razorpay_signature. The server checks them.
      handler: async (response) => resolve(await api("/payments/verify", { method: "POST", token, body: response })),
      modal: { ondismiss: () => resolve({ ok: false, dismissed: true }) },
    });
    rzp.open();
  });
}
