export default function Placeholder({ title }) {
  return (
    <div>
      <h1 className="text-2xl font-bold text-neutral-800 mb-2">{title}</h1>
      <p className="text-neutral-400">
        Esta sección se construirá cuando el endpoint de la API esté listo.
      </p>
    </div>
  )
}