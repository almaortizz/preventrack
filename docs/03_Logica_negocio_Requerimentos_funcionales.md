# PREVENTRACK
# Lógica del Negocio y Requerimientos Funcionales

**Proyecto:** Preventrack - Sistema Integral de Preventa y Gestión de Distribución Comercial

**Versión:** 1.0

**Fecha:** Julio 2026

---

# Introducción

El presente documento describe la lógica del negocio y los requerimientos funcionales que regirán el funcionamiento del sistema **Preventrack**. Estas especificaciones fueron obtenidas durante el levantamiento de requerimientos realizado con el propietario de la distribuidora y constituyen la base para el diseño de la base de datos, la arquitectura del sistema y el desarrollo de la aplicación móvil y el panel administrativo.

---

# Lógica del Negocio

## Gestión de Usuarios

- El administrador será el encargado de registrar, consultar, modificar, activar, desactivar y eliminar usuarios del sistema.
- Cada usuario tendrá un rol asignado que determinará los permisos disponibles.
- Un mismo colaborador podrá desempeñar funciones de preventista y colaborador de entrega, según las necesidades de la empresa.

---

## Gestión de Productos

- El administrador podrá registrar, consultar, modificar y eliminar productos.
- Cada producto pertenecerá a una categoría.
- De cada producto se almacenará:
  - Código.
  - Nombre.
  - Descripción.
  - Categoría.
  - Precio de venta.
  - Costo.
  - Existencia de referencia.
  - Imagen.
- El sistema **no descontará automáticamente el inventario** al registrar un pedido.
- El administrador verificará manualmente la disponibilidad de los productos antes de preparar un pedido.

---

## Gestión de Clientes

- El administrador podrá registrar, consultar, modificar y eliminar clientes.
- Cada cliente podrá tener uno o varios domicilios registrados.
- Para cada cliente se almacenará la siguiente información:
  - Nombre del negocio.
  - Propietario.
  - Razón social.
  - RFC.
  - Teléfono.
  - Zona.

---

## Gestión de Pedidos

- El colaborador registrará los pedidos desde la aplicación móvil.
- Al registrar un pedido, el sistema almacenará automáticamente:
  - Fecha.
  - Hora.
  - Coordenadas GPS del lugar donde se realizó el pedido.
- Todo pedido será registrado inicialmente con estado **Pendiente**.
- El administrador consultará los pedidos pendientes desde el panel administrativo.
- El administrador verificará manualmente la disponibilidad de los productos.
- Una vez preparado el pedido, asignará al colaborador encargado de realizar la entrega.
- El pedido cambiará al estado **En ruta**.
- Una vez entregado el pedido, el administrador o colaborador actualizará su estado a **Entregado**.
- Si el pedido es cancelado antes de la entrega, cambiará al estado **Cancelado**.
- Si el cliente no recibe el pedido, éste volverá al estado **Pendiente** para programar una nueva entrega.
- Un pedido únicamente podrá modificarse antes de imprimir el ticket.
- Un pedido únicamente podrá cancelarse antes de ser entregado.

---

## Gestión de Entregas

- El colaborador asignado realizará la entrega del pedido.
- Al finalizar la entrega se registrará:
  - Fecha.
  - Hora.
- El estado del pedido será actualizado según corresponda:
  - Entregado.
  - Pendiente (si no pudo entregarse).
- No se almacenarán fotografías ni firmas como evidencia de entrega.

---

## Gestión de Rutas

- Las rutas serán creadas por el administrador o supervisor.
- Cada ruta podrá contener varios clientes.
- El colaborador podrá modificar el orden de visita de los clientes asignados.
- Cuando un cliente no sea visitado, quedará marcado como pendiente dentro de la ruta.

---

## Jornada Laboral

El colaborador deberá registrar obligatoriamente:

- Inicio de jornada.
- Inicio de comida.
- Fin de comida.
- Fin de jornada.

Un colaborador no podrá iniciar una nueva jornada mientras exista una jornada anterior sin finalizar.

---

## Cuotas y Comisiones

- Las cuotas serán semanales.
- El administrador podrá configurar:
  - La cuota semanal.
  - El monto de la comisión.
- El sistema calculará automáticamente la comisión cuando el colaborador alcance la cuota establecida.

---

## Impresión de Tickets

Una vez registrado un pedido, el sistema permitirá imprimir un ticket mediante una impresora térmica Bluetooth.

El ticket contendrá:

- Datos de la empresa.
- Número de pedido.
- Fecha.
- Hora.
- Cliente.
- Productos.
- Cantidades.
- Precio unitario.
- Total.
- Nombre del preventista.

El sistema permitirá reimprimir el ticket cuando sea necesario.

---

## Funcionamiento sin Conexión

Cuando no exista conexión a Internet, el colaborador podrá:

- Registrar pedidos.
- Consultar clientes.
- Consultar productos.
- Registrar entregas.
- Consultar rutas.
- Imprimir tickets.

Cuando la conexión sea restablecida, la información será sincronizada automáticamente con el servidor.

---

## Dashboard Administrativo

El panel administrativo mostrará información resumida para facilitar el seguimiento de las operaciones diarias, incluyendo:

- Pedidos pendientes.
- Pedidos en ruta.
- Pedidos entregados.
- Ventas del día.
- Últimos pedidos registrados.

---

# Requerimientos Funcionales

## RF-01. Inicio de Sesión

El sistema deberá permitir el acceso mediante usuario y contraseña.

---

## RF-02. Gestión de Usuarios

El administrador podrá registrar, consultar, modificar, activar, desactivar y eliminar usuarios, así como asignarles un rol dentro del sistema.

---

## RF-03. Gestión de Productos

El administrador podrá administrar productos y categorías.

---

## RF-04. Gestión de Clientes

El administrador podrá administrar clientes y sus domicilios.

---

## RF-05. Registro de Pedidos

El colaborador podrá registrar pedidos desde la aplicación móvil.

---

## RF-06. Gestión de Pedidos

El administrador podrá consultar, asignar y dar seguimiento a los pedidos registrados.

---

## RF-07. Gestión de Entregas

El colaborador podrá actualizar el estado de los pedidos asignados una vez realizada la entrega.

---

## RF-08. Gestión de Rutas

El administrador o supervisor podrá crear rutas y asignarlas a los colaboradores.

---

## RF-09. Registro de Ubicación

El sistema registrará automáticamente las coordenadas GPS al momento de registrar un pedido.

---

## RF-10. Registro de Jornada Laboral

El colaborador podrá registrar:

- Inicio de jornada.
- Inicio de comida.
- Fin de comida.
- Fin de jornada.

---

## RF-11. Cuotas y Comisiones

El administrador podrá configurar la cuota semanal y el monto de la comisión.

El sistema calculará automáticamente las comisiones correspondientes.

---

## RF-12. Impresión de Tickets

El sistema permitirá imprimir y reimprimir tickets mediante impresoras térmicas Bluetooth.

---

## RF-13. Reportes

El administrador podrá generar reportes de:

- Ventas.
- Pedidos.
- Clientes.
- Productos.
- Rutas.
- Jornadas laborales.
- Comisiones.

---

## RF-14. Funcionamiento sin Conexión

La aplicación permitirá operar sin conexión a Internet y sincronizará automáticamente la información cuando exista conectividad.

---

## RF-15. Dashboard Administrativo

El sistema mostrará indicadores operativos para facilitar el seguimiento de las actividades diarias.

---

# Observaciones

- El inventario será únicamente de consulta y administración manual; el sistema no descontará automáticamente existencias al registrar pedidos.
- La disponibilidad de los productos será validada por el administrador antes de preparar el pedido.
- No se implementará envío de tickets mediante WhatsApp en la primera versión del sistema.
- No se almacenarán fotografías como evidencia de entrega.
- El seguimiento de nuevos pedidos se realizará mediante el Dashboard Administrativo y el módulo de pedidos, sin utilizar un sistema de notificaciones internas.
- Los estados oficiales de los pedidos serán:
  - Pendiente.
  - En ruta.
  - Entregado.
  - Cancelado.