# Recursos EXISTENTES que este repo no despliega, solo referencia.

# Lambda RecMicroservicios: destino del API Ext y productor de la cola de
# facturacion. De aqui se toma tambien su rol para la queue policy.
data "aws_lambda_function" "recmicroservicios" {
  count = var.recmicroservicios_function_name != "" ? 1 : 0

  function_name = var.recmicroservicios_function_name
}
