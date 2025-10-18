enum UserRole {
  fieldIncharge,
  clusterIncharge,
  territoryIncharge,
  customerSupport,
  manager,
  admin,
  farmer,
}

extension RolePretty on UserRole {
  String get label {
    switch (this) {
      case UserRole.fieldIncharge: return 'Field Incharge';
      case UserRole.clusterIncharge: return 'Cluster Incharge';
      case UserRole.territoryIncharge: return 'Territory Incharge';
      case UserRole.customerSupport: return 'Customer Support';
      case UserRole.manager: return 'Manager';
      case UserRole.admin: return 'Admin';
      case UserRole.farmer: return 'Farmer';
    }
  }
}
