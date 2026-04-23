###############################################################################
# Security Group Module
#
# Creates:
#   - Individual security groups based on a map.
#   - Separate security group rules to avoid circular dependencies.
###############################################################################

resource "aws_security_group" "this" {
  for_each    = var.security_groups
  name        = "${var.prefix}-${each.key}-sg"
  description = each.value.description
  vpc_id      = var.vpc_id

  # Keep tags for the SG itself
  tags = merge(var.common_tags, each.value.tags, {
    Name = "${var.prefix}-${each.key}-sg"
  })

  # We use lifecycle ignore just in case something tries to add inline rules later
  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# Ingress Rules
###############################################################################
locals {
  # Flatten the ingress rules into a list of objects for for_each
  ingress_rules = flatten([
    for sg_key, sg_val in var.security_groups : [
      for idx, rule in sg_val.ingress_rules : {
        key              = "${sg_key}-ingress-${idx}"
        security_group_id = aws_security_group.this[sg_key].id
        from_port        = rule.from_port
        to_port          = rule.to_port
        protocol         = rule.protocol
        cidr_blocks      = rule.cidr_blocks
        # Resolve ID from key if provided, else use first provided ID, else null
        source_security_group_id = rule.source_security_group_key != null ? aws_security_group.this[rule.source_security_group_key].id : (length(rule.security_groups) > 0 ? rule.security_groups[0] : null)
        self             = rule.self
        description      = rule.description
      }
    ]
  ])

  # Flatten egress rules
  egress_rules = flatten([
    for sg_key, sg_val in var.security_groups : [
      for idx, rule in sg_val.egress_rules : {
        key              = "${sg_key}-egress-${idx}"
        security_group_id = aws_security_group.this[sg_key].id
        from_port        = rule.from_port
        to_port          = rule.to_port
        protocol         = rule.protocol
        cidr_blocks      = rule.cidr_blocks
        # Resolve ID from key if provided, else use first provided ID, else null
        source_security_group_id = rule.source_security_group_key != null ? aws_security_group.this[rule.source_security_group_key].id : (length(rule.security_groups) > 0 ? rule.security_groups[0] : null)
        self             = rule.self
        description      = rule.description
      }
    ]
  ])
}

resource "aws_security_group_rule" "ingress" {
  for_each = { for rule in local.ingress_rules : rule.key => rule }

  type              = "ingress"
  security_group_id = each.value.security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol

  # Only one of these can be set
  cidr_blocks              = each.value.self || each.value.source_security_group_id != null ? null : (length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null)
  source_security_group_id = each.value.source_security_group_id
  self                     = each.value.self ? true : null

  description = each.value.description
}

resource "aws_security_group_rule" "egress" {
  for_each = { for rule in local.egress_rules : rule.key => rule }

  type              = "egress"
  security_group_id = each.value.security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol

  # Only one of these can be set
  cidr_blocks              = each.value.self || each.value.source_security_group_id != null ? null : (length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null)
  source_security_group_id = each.value.source_security_group_id
  self                     = each.value.self ? true : null

  description = each.value.description
}
