Proyecto: CloudGram - EC2 + RDS + Bastion Host en AWS

Este proyecto lo hice para seguir practicando cómo montar una arquitectura real en AWS usando Terraform. La idea es tener una aplicación web (Flask con Docker) corriendo en una instancia EC2, conectada a una base de datos PostgreSQL en RDS. También tengo un Bastion Host configurado para acceder a la base de datos de forma segura.

Toda la infraestructura está automatizada con Terraform, y me aseguré de seguir buenas prácticas de red, subredes, y seguridad.

¿Qué usé en este proyecto?

    AWS EC2 para alojar la app Flask

    AWS RDS (PostgreSQL) para guardar los datos

    Bastion Host para conectarme a RDS sin exponerla a internet

    VPC con subredes públicas y privadas bien definidas

    NAT Gateway para que las subredes privadas puedan salir a internet

    Security Groups configurados con acceso solo desde mi IP

    Terraform para desplegar todo como infraestructura como código


Cómo desplegarlo

    Clonar el proyecto y entrar a la carpeta

    Ejecutar terraform init

    Luego terraform apply y esperar a que se creen los recursos

    Conectarte por SSH al Bastion Host usando tu clave

    Desde el Bastion, conectarte a la base de datos RDS

    Subir tu app Flask al EC2 y correrla con Docker o Gunicorn

¿Por qué hice esto?

Quiero trabajar como administrador Linux y arquitecto de soluciones en AWS, así que este tipo de proyectos me sirven para demostrar que sé montar infra en la nube de forma segura, ordenada y funcional. Lo hice todo paso a paso, sin atajos, y controlando bien cada parte del proceso.
