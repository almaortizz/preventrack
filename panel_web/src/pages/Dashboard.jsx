export default function Dashboard() {
  return (
    <div>
      <h1 className="text-2xl font-bold text-neutral-800 mb-6">Dashboard</h1>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Ventas del mes', value: '—' },
          { label: 'Clientes activos', value: '—' },
          { label: 'Cotizaciones pendientes', value: '—' },
          { label: 'Visitas hoy', value: '—' },
        ].map((card) => (
          <div
            key={card.label}
            className="bg-white rounded-xl shadow-sm p-5 border border-neutral-100"
          >
            <p className="text-sm text-neutral-400">{card.label}</p>
            <p className="text-3xl font-bold text-primary mt-2">
              {card.value}
            </p>
          </div>
        ))}
      </div>
      <p className="text-neutral-400 text-sm mt-6">
        Este panel se irá conectando a los endpoints de la API conforme estén
        disponibles.
      </p>
    </div>
  )
}
