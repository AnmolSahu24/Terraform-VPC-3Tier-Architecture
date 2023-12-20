

###### Create a launch configuration for the EC2 instances #####
resource "aws_launch_configuration" "three-tier-web-lconfig" {
  name_prefix                 = "three-tier-web-lconfig"
  image_id                    = "ami-0b3a4110c36b9a5f0"
  instance_type               = "t2.micro"
  key_name                    = "three-tier-web-asg-kp"
  security_groups             = [aws_security_group.three-tier-ec2-asg-sg.id]
  user_data                   = <<-EOF
                                #!/bin/bash

                                # Update the system
                                sudo yum -y update

                                # Install Apache web server
                                sudo yum -y install httpd

                                # Start Apache web server
                                sudo systemctl start httpd.service

                                # Enable Apache to start at boot
                                sudo systemctl enable httpd.service

                                # Create index.html file with your custom HTML
                                sudo echo '
                                <!DOCTYPE html>
                                <html lang="en">
                                    <head>
                                        <meta charset="utf-8" />
                                        <meta name="viewport" content="width=device-width, initial-scale=1" />

                                        <title>A Basic HTML5 Template</title>

                                        <link rel="preconnect" href="https://fonts.googleapis.com" />
                                        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
                                        <link
                                            href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700;800&display=swap"
                                            rel="stylesheet"
                                        />

                                        <link rel="stylesheet" href="css/styles.css?v=1.0" />
                                    </head>

                                    <body>
                                        <div class="wrapper">
                                            <div class="container">
                                                <h1>Welcome! An Apache web server has been started successfully.</h1>
                                            </div>
                                        </div>
                                    </body>
                                </html>

                                <style>
                                    body {
                                        background-color: #34333d;
                                        display: flex;
                                        align-items: center;
                                        justify-content: center;
                                        font-family: Inter;
                                        padding-top: 128px;
                                    }

                                    .container {
                                        box-sizing: border-box;
                                        width: 741px;
                                        height: 449px;
                                        display: flex;
                                        flex-direction: column;
                                        justify-content: center;
                                        align-items: flex-start;
                                        padding: 48px 48px 48px 48px;
                                        box-shadow: 0px 1px 32px 11px rgba(38, 37, 44, 0.49);
                                        background-color: #5d5b6b;
                                        overflow: hidden;
                                        align-content: flex-start;
                                        flex-wrap: nowrap;
                                        gap: 24;
                                        border-radius: 24px;
                                    }

                                    .container h1 {
                                        flex-shrink: 0;
                                        width: 100%;
                                        height: auto; /* 144px */
                                        position: relative;
                                        color: #ffffff;
                                        line-height: 1.2;
                                        font-size: 40px;
                                    }
                                    .container p {
                                        position: relative;
                                        color: #ffffff;
                                        line-height: 1.2;
                                        font-size: 18px;
                                    }
                                </style>
                                ' > /var/www/html/index.html

                                EOF
                                
  associate_public_ip_address = true
  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_autoscaling_group" "three-tier-web-asg" {
  name                 = "three-tier-web-asg"
  launch_configuration = aws_launch_configuration.three-tier-web-lconfig.id
  vpc_zone_identifier  = [aws_subnet.three-tier-pub-sub-1.id, aws_subnet.three-tier-pub-sub-2.id]
  min_size             = 2
  max_size             = 3
  desired_capacity     = 2
}


# Create Load balancer - web tier
resource "aws_lb" "three-tier-web-lb" {
  name               = "three-tier-web-lb"
  internal           = true
  load_balancer_type = "application"
  
  security_groups    = [aws_security_group.three-tier-alb-sg-1.id]
  subnets            = [aws_subnet.three-tier-pub-sub-1.id, aws_subnet.three-tier-pub-sub-2.id]

  tags = {
    Environment = "three-tier-web-lb"
  }
}

# create load balancer target group - web tier

resource "aws_lb_target_group" "three-tier-web-lb-tg" {
  name     = "three-tier-web-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.three-tier-vpc.id

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create Load Balancer listener - web tier
resource "aws_lb_listener" "three-tier-web-lb-listner" {
  load_balancer_arn = aws_lb.three-tier-web-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.three-tier-web-lb-tg.arn
  }
}

# Register the instances with the target group - web tier
resource "aws_autoscaling_attachment" "three-tier-web-asattach" {
  autoscaling_group_name = aws_autoscaling_group.three-tier-web-asg.name
  lb_target_group_arn   = aws_lb_target_group.three-tier-web-lb-tg.arn
  
}




# Create an EC2 Auto Scaling Group - app
resource "aws_autoscaling_group" "three-tier-app-asg" {
  name                 = "three-tier-app-asg"
  launch_configuration = aws_launch_configuration.three-tier-app-lconfig.id
  vpc_zone_identifier  = [aws_subnet.three-tier-pvt-sub-1.id, aws_subnet.three-tier-pvt-sub-2.id]
  min_size             = 2
  max_size             = 3
  desired_capacity     = 2
}

# Create a launch configuration for the EC2 instances
resource "aws_launch_configuration" "three-tier-app-lconfig" {
  name_prefix                 = "three-tier-app-lconfig"
  image_id                    = "ami-0b3a4110c36b9a5f0"
  instance_type               = "t2.micro"
  key_name                    = "three-tier-app-asg-kp"
  security_groups             = [aws_security_group.three-tier-ec2-asg-sg-app.id]
  user_data                   = <<-EOF
                                #!/bin/bash

                                sudo yum install mysql -y

                                EOF
                                
  associate_public_ip_address = false
  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}
