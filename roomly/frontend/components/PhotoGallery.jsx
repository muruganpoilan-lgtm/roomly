"use client";

import { useRef } from "react";
import Ridge from "./Ridge";

// One large photo, four smaller ones, and a full-screen viewer for the rest.
export default function PhotoGallery({ photos, name, seed }) {
  const dialog = useRef(null);
  if (!photos.length) {
    return (
      <div className="gallery gallery-empty">
        <Ridge seed={seed} w={800} h={400} className="gallery-ridge" />
        <p>The owner hasn't added photos yet</p>
      </div>
    );
  }
  const shown = photos.slice(0, 5);
  const open = () => dialog.current && dialog.current.showModal();
  return (
    <>
      <div className={`gallery gallery-${Math.min(shown.length, 5)}`}>
        {shown.map((url, i) => (
          <button type="button" key={url} className="gallery-cell" onClick={open} aria-label={`Open photo ${i + 1} of ${photos.length}`}>
            <img src={url} alt={i === 0 ? name : ""} loading={i === 0 ? "eager" : "lazy"} />
          </button>
        ))}
        {photos.length > 1 && (
          <button type="button" className="gallery-all" onClick={open}>
            Show all {photos.length} photos
          </button>
        )}
      </div>
      <dialog ref={dialog} className="viewer" aria-label={`Photos of ${name}`} onClick={(e) => e.target === dialog.current && dialog.current.close()}>
        <button type="button" className="viewer-close btn btn-small" onClick={() => dialog.current.close()}>
          Close
        </button>
        <div className="viewer-list">
          {photos.map((url, i) => (
            <img key={url} src={url} alt={`${name}, photo ${i + 1}`} loading="lazy" />
          ))}
        </div>
      </dialog>
    </>
  );
}
