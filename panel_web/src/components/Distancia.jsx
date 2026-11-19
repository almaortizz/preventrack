// Distancia (en metros) entre donde estaba el preventista y el domicilio del
// cliente, siempre con la precisión del GPS. Desde 200 m se resalta en rojo.
const DISTANCIA_LEJANA_M = 200

export default function Distancia({ metros, precision }) {
  if (metros == null) {
    return <span className="text-neutral-400">Sin GPS</span>
  }

  const lejos = Number(metros) >= DISTANCIA_LEJANA_M
  const textoPrecision =
    precision != null ? `±${Math.round(Number(precision))} m` : 'no registrada'

  return (
    <span className={lejos ? 'text-red-600 font-semibold' : 'text-neutral-800'}>
      {Math.round(Number(metros))} m{lejos && ' ⚠'}
      <span className="text-neutral-400 font-normal text-xs ml-1">
        (precisión {textoPrecision})
      </span>
    </span>
  )
}
