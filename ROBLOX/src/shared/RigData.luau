-- gerado por SCRIPTS/tools/gen_rig_data.py a partir do rig do Blender, não editar na mão

return {
	{
		name = "EmberBlade",
		parent = "RightHand",
		joint = "EmberBladeGrip",
		size = Vector3.new(0.14, 0.32, 5.2),
		c0 = CFrame.new(0, -0.029954, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		c1 = CFrame.new(0, 0, 2.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
	{
		name = "AzureBlade",
		parent = "LeftHand",
		joint = "AzureBladeGrip",
		size = Vector3.new(0.14, 0.32, 5.2),
		c0 = CFrame.new(0, -0.029954, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		c1 = CFrame.new(0, 0, 2.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
	{
		name = "Scarf1",
		parent = "UpperTorso",
		joint = "ScarfJoint1",
		size = Vector3.new(0.72, 0.86, 0.08),
		c0 = CFrame.new(0, 0.650017, 0.58, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		c1 = CFrame.new(0, 0.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
	{
		name = "Scarf2",
		parent = "Scarf1",
		joint = "ScarfJoint2",
		size = Vector3.new(0.68, 0.86, 0.08),
		c0 = CFrame.new(0, -0.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		c1 = CFrame.new(0, 0.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
	{
		name = "Scarf3",
		parent = "Scarf2",
		joint = "ScarfJoint3",
		size = Vector3.new(0.62, 0.86, 0.08),
		c0 = CFrame.new(0, -0.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		c1 = CFrame.new(0, 0.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
	{
		name = "Scarf4",
		parent = "Scarf3",
		joint = "ScarfJoint4",
		size = Vector3.new(0.54, 0.86, 0.08),
		c0 = CFrame.new(0, -0.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		c1 = CFrame.new(0, 0.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
}
