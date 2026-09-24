# 2. Sin NAT Gateway: nodos EKS en subredes públicas

Date: 2026-09-24

## Status

Accepted

## Context

Un NAT Gateway cuesta ~0,045 $/h (~32 $/mes) más el tráfico procesado,
solo por existir — antes de que salga un solo byte de tráfico real. Para
un proyecto de demo/portfolio que se levanta unas horas y se destruye
(`terraform destroy` al terminar, ver README), ese coste fijo es
desproporcionado frente al del propio cluster.

## Decision

`infra/modules/network` pone `enable_nat_gateway = false`. Los nodos de
EKS (`infra/modules/eks`) viven en las subredes **públicas** de la VPC en
vez de en las privadas: así tienen salida directa a internet vía Internet
Gateway (para tirar de imágenes de contenedor, llegar al endpoint de la
API de EKS, etc.) sin necesitar NAT.

Las subredes privadas se quedan solo para RDS, que no necesita salida a
internet en absoluto — su security group únicamente acepta tráfico desde
el security group de los nodos.

## Consequences

- **Ahorro real**: nos ahorramos el NAT Gateway por completo mientras el
  cluster está levantado.
- **Los nodos tienen IP pública** y quedan expuestos a internet a nivel
  de red (mitigado por los security groups — solo el tráfico que
  Kubernetes/EKS necesita— pero es una superficie de ataque mayor que
  con nodos puramente privados).
- **No es la topología que se recomienda en producción real** en un
  entorno con datos sensibles o cumplimiento normativo — ahí sí
  querrías nodos en subredes privadas con NAT Gateway (o NAT
  instances/VPC endpoints como alternativa más barata). Para `linkly`
  el trade-off coste-vs-aislamiento se acepta explícitamente porque el
  cluster no vive levantado de forma permanente.
