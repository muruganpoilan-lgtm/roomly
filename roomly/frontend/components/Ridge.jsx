// Western Ghats-style ridgelines drawn as SVG. Deterministic from `seed`, so the same property
// always gets the same picture. Used in the hero and as the stand-in when a property has no photos.
function rng(seed) {
  let a = 0;
  for (const ch of String(seed)) a = (a * 31 + ch.charCodeAt(0)) >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const SKIES = ["#e6efe8", "#f6ecd2", "#e3e8f1", "#eaf0e2"];
const LAYERS = ["#b7cdbd", "#7aa38f", "#2f6b57"];

function ridgePath(rand, w, h, base, amp) {
  const steps = 7;
  const pts = [];
  for (let i = 0; i <= steps; i++) pts.push([(w / steps) * i, base - rand() * amp]);
  let d = `M0 ${h} L${pts[0][0]} ${pts[0][1].toFixed(1)}`;
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1];
    const [x1, y1] = pts[i];
    const mx = (x0 + x1) / 2;
    d += ` C${mx.toFixed(1)} ${y0.toFixed(1)} ${mx.toFixed(1)} ${y1.toFixed(1)} ${x1.toFixed(1)} ${y1.toFixed(1)}`;
  }
  return `${d} L${w} ${h} Z`;
}

export default function Ridge({ seed = "roomly", w = 400, h = 300, sky = true, colors = LAYERS, className, title }) {
  const rand = rng(seed);
  const skyColor = SKIES[Math.floor(rand() * SKIES.length)];
  const sunX = w * (0.2 + rand() * 0.6);
  const paths = colors.map((c, i) => ({
    c,
    d: ridgePath(rand, w, h, h * (0.52 + i * 0.17), h * (0.3 - i * 0.04)),
  }));
  return (
    <svg className={className} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="xMidYMax slice" role={title ? "img" : undefined} aria-hidden={title ? undefined : "true"} aria-label={title}>
      {sky && <rect width={w} height={h} fill={skyColor} />}
      {sky && <circle cx={sunX} cy={h * 0.24} r={h * 0.075} fill="#f4b000" />}
      {paths.map((p, i) => (
        <path key={i} d={p.d} fill={p.c} />
      ))}
    </svg>
  );
}
