#
# Resources Created
#  * IAM Role to allow EKS to manage other AWS services
#  * IAM Role to allow EC2 to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster and worker nodes
#  * Create EKS Cluster and Install other dependencies
#

#EKS Cluster IAM Role Creation
resource "aws_iam_role" "eks-cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster.name
}



#EKS Node IAM Role Creation######

resource "aws_iam_role" "eks-node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy" "cluster-autoscaler-policy" {
  name = "cluster-autoscaler"
  role = aws_iam_role.eks-node.name

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}
resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-node.name
}


resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-node.name
}

resource "aws_iam_role_policy_attachment" "node-AWSKeyManagementServicePowerUser" {
  policy_arn = "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser"
  role       = aws_iam_role.eks-node.name
}

resource "aws_iam_role_policy_attachment" "node-AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = aws_iam_role.eks-node.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-node.name
}

resource "aws_iam_instance_profile" "eks-node" {
  name = "${var.cluster_name}-node-instance-profile"
  role = aws_iam_role.eks-node.name
  #role = var.eks_node_role
}

#EKS Cluster Security #####
resource "aws_security_group" "eks-cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

resource "aws_security_group_rule" "eks-cluster-ingress-self" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks-cluster.id
  source_security_group_id = aws_security_group.eks-cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cluster.id
  source_security_group_id = aws_security_group.eks-node.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-cluster-ingress-node-kube" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cluster.id
  source_security_group_id = aws_security_group.eks-node.id
  to_port                  = 10250
  type                     = "ingress"
}


### EKS Node Security Group ####
resource "aws_security_group" "eks-node" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name"                                      = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group_rule" "eks-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks-node.id
  source_security_group_id = aws_security_group.eks-node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-node.id
  source_security_group_id = aws_security_group.eks-cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-node-ingress-cluster-https" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-node.id
  source_security_group_id = aws_security_group.eks-cluster.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-node-ingress-ssh" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-node.id
  source_security_group_id = var.ec2_sg_id_for_ssh
  to_port                  = 22
  type                     = "ingress"
}

#Creating EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks-cluster.arn
  version  = 1.17
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids = [aws_security_group.eks-cluster.id]
    subnet_ids         = var.all_subnet_ids
  }


  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy,
  ]
}

#Configure AWS-Auth CM and Provide permission to Node Role
resource "null_resource" "aws_auth_update" {

  provisioner "local-exec" {
    command = "eksctl create iamidentitymapping --cluster ${var.cluster_name} --arn ${aws_iam_role.eks-node.arn} --group system:nodes --group system:bootstrappers --username system:node:{{EC2PrivateDNSName}}"
  }

  depends_on = [
    aws_eks_cluster.eks,
  ]
}

#Update kubeconfig to local
resource "null_resource" "update_kubeconfig" {

  provisioner "local-exec" {
    command = "aws eks --region ${var.location} update-kubeconfig --name ${var.cluster_name}"
  }

  depends_on = [
    null_resource.aws_auth_update,
  ]
}

#Install Metric Server
resource "null_resource" "install_metrics_server" {

  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  }

  depends_on = [
    null_resource.update_kubeconfig,
  ]
}

