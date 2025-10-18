class Roles {
  static const fieldIncharge     = 'field_incharge';
  static const territoryIncharge = 'territory_incharge';
  static const clusterIncharge   = 'cluster_incharge';
  static const manager           = 'manager';
  static const admin             = 'admin';
  static const superUser         = 'super';
  static const superAdmin        = 'super_admin';
  static const customerSupport   = 'customer_support';
}

/// Everyone at/above Field Incharge:
const kFieldAndUp = {
  Roles.fieldIncharge,
  Roles.territoryIncharge,
  Roles.clusterIncharge,
  Roles.manager,
  Roles.admin,
  Roles.superUser,
  Roles.superAdmin,
};

const kManagersAndFieldAndSupport = {
  Roles.manager,
  Roles.fieldIncharge,
  Roles.customerSupport,
  Roles.admin,
  Roles.superUser,
  Roles.superAdmin,
};


const kSupers = {Roles.superUser, Roles.superAdmin};
const kManagers = {Roles.manager, ...kSupers};
const kSupport = {Roles.customerSupport, ...kSupers};


/// Convenience helpers
bool isCIC(String? role) => role == Roles.clusterIncharge;
bool isFIC(String? role) => role == Roles.fieldIncharge;