class UserDemographicsReportsData {
  final int activeUsers;
  final int newlyRegisteredUsers;
  final int affiliatedUsers;
  final int totalUsers;
  final Map<String, int> usersByYear;
  final Map<String, int> usersByProgram;
  final Map<String, int>? userAffiliations;



  final Map<String, int>?
  scholarshipTypes; 
  final Map<String, int>? enrollmentStatus; 

  const UserDemographicsReportsData({
    required this.activeUsers,
    required this.newlyRegisteredUsers,
    required this.affiliatedUsers,
    required this.totalUsers,
    required this.usersByYear,
    required this.usersByProgram,
    required this.userAffiliations,

    required this.scholarshipTypes,
    required this.enrollmentStatus,
  });
}

UserDemographicsReportsData getEmptyUserDemographicsReportsData() {
  return const UserDemographicsReportsData(
    activeUsers: 0,
    newlyRegisteredUsers: 0,
    affiliatedUsers: 0,
    totalUsers: 0,
    usersByYear: {},
    usersByProgram: {},
    userAffiliations: {},
 
    scholarshipTypes: {},
    enrollmentStatus: {'Enrolled': 0, 'Not Enrolled': 0},
  );
}