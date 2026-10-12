import { useState } from 'react'

const PESTANAS = [
  { id: 'aviso', label: 'Aviso de Privacidad' },
  { id: 'terminos', label: 'Términos y Condiciones' },
  { id: 'datos', label: 'Datos que se recaban' },
]

function Seccion({ titulo, children }) {
  return (
    <section>
      <h3 className="font-semibold text-neutral-800 mb-1">{titulo}</h3>
      {children}
    </section>
  )
}

function Lista({ items }) {
  return (
    <ul className="list-disc pl-5 space-y-1">
      {items.map((i) => (
        <li key={i}>{i}</li>
      ))}
    </ul>
  )
}

function Punto({ n, titulo, children }) {
  return (
    <p>
      <b>
        {n}. {titulo}:
      </b>{' '}
      {children}
    </p>
  )
}

// Mismo texto que el Aviso de Privacidad de la app móvil.
function Aviso() {
  return (
    <>
      <h3 className="font-bold text-neutral-800">Aviso de Privacidad PreventTrack</h3>
      <p>
        Para PreventTrack, la seguridad de sus datos es nuestra prioridad. Este aviso describe
        cómo recopilamos, usamos y protegemos su información personal en el contexto de nuestras
        operaciones de logística y distribución.
      </p>
      <Punto n="1" titulo="Recopilación de Datos">
        Recopilamos información necesaria para la gestión de rutas, identificación de clientes y
        procesamiento de pedidos, incluyendo ubicación en tiempo real para optimización de
        entregas.
      </Punto>
      <Punto n="2" titulo="Uso de la Información">
        Los datos se utilizan exclusivamente para mejorar la eficiencia operativa, asegurar la
        trazabilidad de los productos y facilitar la comunicación entre los agentes de campo y la
        administración.
      </Punto>
      <Punto n="3" titulo="Protección de Datos">
        Implementamos protocolos de cifrado de grado empresarial y controles de acceso estrictos
        para garantizar que su información esté protegida contra accesos no autorizados.
      </Punto>
      <Punto n="4" titulo="Datos Personales Recabados">
        Nombre completo, número de teléfono, nombre de usuario y contraseña, datos de
        geolocalización durante el uso de la aplicación, información de jornada laboral.
      </Punto>
      <Punto n="5" titulo="Derechos ARCO">
        Usted tiene derecho a Acceder, Rectificar, Cancelar u Oponerse al tratamiento de sus datos
        personales contactando al administrador del sistema.
      </Punto>
      <Punto n="6" titulo="Modificaciones">
        Nos reservamos el derecho de modificar este aviso de privacidad. Cualquier cambio será
        notificado a través de la aplicación.
      </Punto>
      <p className="text-neutral-500">Fecha de última actualización: Julio 2026.</p>
    </>
  )
}

// Mismo texto que los Términos y Condiciones de la app móvil.
function Terminos() {
  return (
    <>
      <h3 className="font-bold text-neutral-800">Términos y Condiciones de Uso</h3>
      <p>
        Al utilizar PreventTrack, usted acepta los siguientes términos y condiciones:
      </p>
      <Punto n="1" titulo="Uso de la Aplicación">
        PreventTrack es un sistema de preventa y distribución comercial diseñado para uso
        exclusivo del personal autorizado por la Empresa.
      </Punto>
      <Punto n="2" titulo="Cuenta de Usuario">
        Cada usuario recibe credenciales únicas de acceso. Es responsabilidad del usuario
        mantener la confidencialidad de sus credenciales. No está permitido compartir cuentas de
        usuario. La Empresa puede bloquear o eliminar cuentas en cualquier momento.
      </Punto>
      <Punto n="3" titulo="Obligaciones del Usuario">
        Utilizar la aplicación únicamente para fines laborales autorizados. Mantener actualizada
        su información personal. Reportar cualquier uso no autorizado de su cuenta. No intentar
        acceder a funciones o datos no autorizados para su rol.
      </Punto>
      <Punto n="4" titulo="Geolocalización">
        La aplicación registra su ubicación al momento de crear pedidos. Esta información se
        utiliza para verificar y optimizar las operaciones. El registro de ubicación es un
        requisito operativo del sistema.
      </Punto>
      <Punto n="5" titulo="Propiedad Intelectual">
        Todo el contenido, diseño y funcionalidad de PreventTrack es propiedad de la Empresa.
        Queda prohibida su reproducción total o parcial.
      </Punto>
      <Punto n="6" titulo="Limitación de Responsabilidad">
        La Empresa no será responsable por interrupciones del servicio, pérdida de datos por
        fallos técnicos, o uso indebido de la aplicación por parte del usuario.
      </Punto>
      <Punto n="7" titulo="Jornada Laboral">
        El registro de jornada laboral a través de la aplicación tiene validez como control de
        asistencia. El usuario es responsable de registrar correctamente sus horarios.
      </Punto>
      <Punto n="8" titulo="Modificaciones">
        La Empresa se reserva el derecho de modificar estos términos en cualquier momento. Los
        cambios entrarán en vigor al ser publicados en la aplicación.
      </Punto>
      <p className="text-neutral-500">Fecha de última actualización: Julio 2026.</p>
    </>
  )
}

function Datos() {
  return (
    <>
      <p>Esta es la información que PreventTrack guarda para funcionar.</p>

      <Seccion titulo="1. Usuarios (administradores y preventistas)">
        <Lista
          items={[
            'Nombre y apellidos',
            'Edad',
            'Teléfono',
            'Dirección',
            'Usuario y contraseña (guardada cifrada)',
            'Color asignado (para identificarlo en el mapa)',
            'Aceptación de términos y su fecha',
          ]}
        />
      </Seccion>

      <Seccion titulo="2. Clientes">
        <Lista
          items={[
            'Folio',
            'Nombre del negocio',
            'Propietario',
            'Teléfono',
            'Zona',
            'Razón social y RFC (si aplica)',
            'Dirección, municipio y ubicación en el mapa (latitud y longitud)',
          ]}
        />
      </Seccion>

      <Seccion titulo="3. Operación">
        <Lista
          items={[
            'Pedidos y ventas: productos, cantidades, total, descuento, estado, fecha y quién vendió o entregó',
            'Cuotas de venta de cada preventista',
            'Rutas y visitas: paradas, orden y estado de cada una',
          ]}
        />
      </Seccion>

      <Seccion titulo="4. Ubicación del preventista">
        <Lista
          items={[
            'Ubicación al iniciar la jornada',
            'Ubicación en vivo, cada 90 segundos, solo mientras la jornada está activa',
            'Hora de inicio y fin de la jornada',
          ]}
        />
      </Seccion>

      <Seccion titulo="5. Productos">
        <Lista items={['Código, nombre, precio, costo, stock, categoría e imagen']} />
      </Seccion>
    </>
  )
}

export default function Footer() {
  const [activa, setActiva] = useState(null) // 'aviso' | 'terminos' | 'datos' | null
  const cerrar = () => setActiva(null)

  return (
    <>
      <footer className="text-center py-5">
        <span className="inline-block border-t border-neutral-300 pt-3 px-2 text-sm text-neutral-500">
          © 2026 Sistema Web PreventTrack ·{' '}
          <button
            type="button"
            onClick={() => setActiva('aviso')}
            className="text-secondary hover:underline"
          >
            Política de privacidad
          </button>
        </span>
      </footer>

      {activa && (
        <div
          className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
          onClick={cerrar}
        >
          <div
            className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[85vh] flex flex-col text-left"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between px-6 py-4">
              <h2 className="text-lg font-bold text-primary">Privacidad</h2>
              <button
                type="button"
                onClick={cerrar}
                className="text-neutral-400 hover:text-neutral-700 text-xl leading-none"
                aria-label="Cerrar"
              >
                ✕
              </button>
            </div>

            <div className="flex gap-1 px-6 border-b border-neutral-100 overflow-x-auto">
              {PESTANAS.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => setActiva(p.id)}
                  className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px whitespace-nowrap ${
                    activa === p.id
                      ? 'border-secondary text-primary'
                      : 'border-transparent text-neutral-400 hover:text-neutral-700'
                  }`}
                >
                  {p.label}
                </button>
              ))}
            </div>

            <div className="overflow-y-auto px-6 py-4 space-y-4 text-sm text-neutral-700">
              {activa === 'datos' ? <Datos /> : activa === 'terminos' ? <Terminos /> : <Aviso />}
            </div>

            <div className="px-6 py-3 border-t border-neutral-100 text-right">
              <button
                type="button"
                onClick={cerrar}
                className="bg-primary text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-primary/90"
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
