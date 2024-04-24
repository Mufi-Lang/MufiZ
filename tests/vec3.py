import numpy as np

x = np.array([1.00, 5.50, 10.00])
y = np.array([2.00, 7.00, 12.00])

print(np.dot(x, y)) # dot product
print(np.cross(x, y)) # cross product
print(x/np.linalg.norm(x)) # normalize x

def projection(u, v):
    return v * np.dot(u, v) / np.dot(v, v)

print(projection(x, y))

def rejection(u, v):
    return u - projection(u, v)
print(rejection(x, y))

def relection(u, v):
    return (projection(u, v) * 2) - u

print(relection(x, y))

def refraction(u, v, n1, n2):
    # Calculate the incident angle
    theta_i = np.arccos(np.dot(u, v) / (np.linalg.norm(u) * np.linalg.norm(v)))

    # Calculate the refracted angle using Snell's law
    sin_theta_r = (n1 / n2) * np.sin(theta_i)

    # Check for total internal reflection
    if sin_theta_r > 1:
        return None

    # Calculate the refracted vector
    cos_theta_r = np.sqrt(1 - sin_theta_r**2)
    refracted = (n1 / n2) * u + (n1 / n2 * cos_theta_r - np.cos(theta_i)) * v

    return refracted

print(refraction(x, y, 1.0, 2.0))