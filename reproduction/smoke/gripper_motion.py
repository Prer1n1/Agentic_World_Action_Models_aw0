print("Initial measured opening:", get_gripper_aperture("left"))

print("Open command:", open_gripper("left"))
opened = get_gripper_aperture("left")
print("Measured opening after open:", opened)

print("Close command:", close_gripper("left"))
closed = get_gripper_aperture("left")
print("Measured opening after close:", closed)

print("Reopen command:", open_gripper("left"))
reopened = get_gripper_aperture("left")
print("Measured opening after reopen:", reopened)

print("Open-minus-closed difference:", opened - closed)
print("Reopened-minus-closed difference:", reopened - closed)
