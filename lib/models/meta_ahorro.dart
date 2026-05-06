class MetaAhorro {
  String nombre;
  double montoMeta;
  double montoActual;
  double ahorroMensual;

  MetaAhorro({
    required this.nombre,
    required this.montoMeta,
    this.montoActual = 0,
    this.ahorroMensual = 0,
  });

  double get progreso => montoActual / montoMeta;

  double get porcentaje => progreso * 100;

  int get mesesRestantes {
    if (ahorroMensual <= 0) return 0;
    double faltante = montoMeta - montoActual;
    return (faltante / ahorroMensual).ceil();
  }
}