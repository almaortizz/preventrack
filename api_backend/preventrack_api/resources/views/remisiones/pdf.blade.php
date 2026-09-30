<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Remisión {{ $venta->numero_orden }}</title>
    <style>
        @page { margin: 20px 25px; }
        body { font-family: 'Helvetica', Arial, sans-serif; font-size: 11px; color: #222; }

        .encabezado { width: 100%; margin-bottom: 10px; }
        .encabezado table { width: 100%; border-collapse: collapse; }
        .encabezado td { vertical-align: top; }
        .logo { width: 90px; }
        .empresa-nombre { font-size: 22px; font-weight: bold; color: #1a3d6d; }
        .empresa-datos { font-size: 10px; color: #333; line-height: 1.5; }
        .titulo-remision {
            text-align: right;
            font-size: 16px;
            font-weight: bold;
            color: #1a3d6d;
        }
        .folio-box {
            text-align: right;
            font-size: 11px;
        }
        .folio-box .numero {
            font-size: 18px;
            font-weight: bold;
            color: #c0392b;
        }

        .linea { border-top: 2px solid #1a3d6d; margin: 8px 0 12px 0; }

        .datos-cliente {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 14px;
        }
        .datos-cliente td {
            padding: 3px 0;
            font-size: 11px;
        }
        .datos-cliente .etiqueta {
            font-weight: bold;
            width: 110px;
        }

        table.productos {
            width: 100%;
            border-collapse: collapse;
            margin-top: 6px;
        }
        table.productos th {
            background-color: #1a3d6d;
            color: #fff;
            font-size: 10px;
            padding: 6px 4px;
            text-align: left;
        }
        table.productos td {
            font-size: 10px;
            padding: 5px 4px;
            border-bottom: 1px solid #ddd;
        }
        table.productos td.num, table.productos th.num { text-align: right; }
        table.productos td.centro, table.productos th.centro { text-align: center; }

        .totales {
            width: 100%;
            margin-top: 10px;
        }
        .totales table {
            width: 220px;
            float: right;
            border-collapse: collapse;
        }
        .totales td {
            padding: 4px 6px;
            font-size: 11px;
        }
        .totales .etiqueta { text-align: left; }
        .totales .valor { text-align: right; }
        .totales .total-final {
            font-weight: bold;
            font-size: 13px;
            border-top: 2px solid #1a3d6d;
            color: #1a3d6d;
        }

        .pie {
            clear: both;
            margin-top: 60px;
            padding-top: 10px;
            border-top: 1px solid #ccc;
            font-size: 9px;
            color: #666;
            text-align: center;
        }

        .firma {
            margin-top: 50px;
            width: 100%;
        }
        .firma table { width: 100%; }
        .firma td {
            text-align: center;
            font-size: 10px;
            padding-top: 4px;
        }
        .firma .raya {
            border-top: 1px solid #333;
            width: 70%;
            margin: 0 auto 4px auto;
        }
    </style>
</head>
<body>

    <div class="encabezado">
        <table>
            <tr>
                <td style="width: 100px;">
                    <img class="logo" src="{{ $logoPath }}">
                </td>
                <td>
                    <div class="empresa-nombre">DISTRIBUIDORA "BELLA LUZ"</div>
                    <div class="empresa-datos">
                        R.F.C. HEAA760906DJ4<br>
                        Calle 95 Oriente # 1015-2, Colonia Granjas Ejidales San Isidro<br>
                        Puebla, Pue. C.P. 72587<br>
                        Cel. 22 24 63 35 56 (WhatsApp) &nbsp;·&nbsp; angelo13467@gmail.com
                    </div>
                </td>
                <td style="width: 160px;">
                    <div class="titulo-remision">REMISIÓN</div>
                    <div class="folio-box">
                        <div class="numero">{{ $venta->numero_orden }}</div>
                        <div>Fecha: {{ \Carbon\Carbon::parse($venta->fecha_hora)->format('d/m/Y') }}</div>
                    </div>
                </td>
            </tr>
        </table>
    </div>

    <div class="linea"></div>

    <table class="datos-cliente">
        <tr>
            <td class="etiqueta">Razón social:</td>
            <td>{{ $cliente->razon_social ?: $cliente->nombre_negocio }}</td>
            <td class="etiqueta">No. cliente:</td>
            <td>{{ $cliente->folio ?? '—' }}</td>
        </tr>
        <tr>
            <td class="etiqueta">Cliente:</td>
            <td>{{ $cliente->nombre_negocio }}</td>
            <td class="etiqueta">Vendedor:</td>
            <td>{{ $venta->vendedor->nombre ?? '—' }} {{ $venta->vendedor->apellidos ?? '' }}</td>
        </tr>
        <tr>
            <td class="etiqueta">Domicilio:</td>
            <td colspan="3">{{ $domicilio->direccion }}{{ $domicilio->municipio ? ', ' . $domicilio->municipio : '' }}</td>
        </tr>
    </table>

    <table class="productos">
        <thead>
            <tr>
                <th class="centro" style="width: 12%;">Cant.</th>
                <th style="width: 18%;">Código</th>
                <th>Concepto</th>
                <th class="num" style="width: 15%;">Precio</th>
                <th class="num" style="width: 15%;">Importe</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($venta->detalle as $item)
                <tr>
                    <td class="centro">{{ $item->cantidad }}</td>
                    <td>{{ $item->producto->codigo ?? '—' }}</td>
                    <td>{{ $item->producto->nombre ?? '—' }}</td>
                    <td class="num">${{ number_format($item->precio_unitario, 2) }}</td>
                    <td class="num">${{ number_format($item->subtotal, 2) }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <div class="totales">
        <table>
            <tr>
                <td class="etiqueta">Subtotal</td>
                <td class="valor">${{ number_format($subtotal, 2) }}</td>
            </tr>
            @if ($venta->descuento > 0)
                <tr>
                    <td class="etiqueta">Descuento</td>
                    <td class="valor">-${{ number_format($venta->descuento, 2) }}</td>
                </tr>
            @endif
            <tr class="total-final">
                <td class="etiqueta">Total</td>
                <td class="valor">${{ number_format($venta->total, 2) }}</td>
            </tr>
        </table>
    </div>

    <div class="firma">
        <table>
            <tr>
                <td style="width: 45%;">
                    <div class="raya"></div>
                    Entregó
                </td>
                <td style="width: 10%;"></td>
                <td style="width: 45%;">
                    <div class="raya"></div>
                    Recibió de conformidad
                </td>
            </tr>
        </table>
    </div>

    <div class="pie">
        Este documento es una remisión de entrega, no tiene validez fiscal como factura. Generado por Preventrack.
    </div>

</body>
</html>
