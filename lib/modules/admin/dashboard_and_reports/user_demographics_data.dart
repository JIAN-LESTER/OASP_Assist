import 'package:capstone_project/modules/admin/dashboard_and_reports/reports.dart';

class UserDemographicsReportsData {
  final int totalUsers;
  final int newUsers;
  final int activeUsers;
  final int inactiveUsers;
  final int enrolledStudents;
  final int incomingFreshmen;
  final Map<String, int> userAffiliations;
  final Map<String, int> scholarshipDistribution;
  final int usersWithScholarship;
  final int usersWithoutScholarship;
  final List<ChartData> userGrowthOverTime;
  final Map<String, int> usersByYear;
  final Map<String, int> usersByProgram;
  final String activeUserRatio;      // ADD THIS
  final String enrolledRatio;        // ADD THIS

  UserDemographicsReportsData({
    required this.totalUsers,
    required this.newUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.enrolledStudents,
    required this.incomingFreshmen,
    required this.userAffiliations,
    required this.scholarshipDistribution,
    required this.usersWithScholarship,
    required this.usersWithoutScholarship,
    required this.userGrowthOverTime,
    required this.usersByYear,
    required this.usersByProgram,
    required this.activeUserRatio,    // ADD THIS
    required this.enrolledRatio,      // ADD THIS
  });

  // Helper getter for active/inactive ratio
  // double get activeUserRatio {
  //   if (totalUsers == 0) return 0.0;
  //   return (activeUsers / totalUsers) * 100;
  // }

  double get inactiveUserRatio {
    if (totalUsers == 0) return 0.0;
    return (inactiveUsers / totalUsers) * 100;
  }

  // // Helper getter for enrolled vs incoming ratio
  // double get enrolledRatio {
  //   final total = enrolledStudents + incomingFreshmen;
  //   if (total == 0) return 0.0;
  //   return (enrolledStudents / total) * 100;
  // }

  double get incomingRatio {
    final total = enrolledStudents + incomingFreshmen;
    if (total == 0) return 0.0;
    return (incomingFreshmen / total) * 100;
  }

  UserDemographicsReportsData copyWith({
    int? totalUsers,
    int? newUsers,
    int? activeUsers,
    int? inactiveUsers,
    int? enrolledStudents,
    int? incomingFreshmen,
    Map<String, int>? userAffiliations,
    Map<String, int>? scholarshipDistribution,
    int? usersWithScholarship,
    int? usersWithoutScholarship,
    List<ChartData>? userGrowthOverTime,
    Map<String, int>? usersByYear,
    Map<String, int>? usersByProgram,


  }) {
    return UserDemographicsReportsData(
      totalUsers: totalUsers ?? this.totalUsers,
      newUsers: newUsers ?? this.newUsers,
      activeUsers: activeUsers ?? this.activeUsers,
      inactiveUsers: inactiveUsers ?? this.inactiveUsers,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      incomingFreshmen: incomingFreshmen ?? this.incomingFreshmen,
      userAffiliations: userAffiliations ?? this.userAffiliations,
      scholarshipDistribution: scholarshipDistribution ?? this.scholarshipDistribution,
      usersWithScholarship: usersWithScholarship ?? this.usersWithScholarship,
      usersWithoutScholarship: usersWithoutScholarship ?? this.usersWithoutScholarship,
      userGrowthOverTime: userGrowthOverTime ?? this.userGrowthOverTime,
      usersByYear: usersByYear ?? this.usersByYear,
      usersByProgram: usersByProgram ?? this.usersByProgram,
          enrolledRatio: enrolledRatio,
    activeUserRatio: activeUserRatio,
    );
  }
}

UserDemographicsReportsData getEmptyUserDemographicsReportsData() {
  return  UserDemographicsReportsData(
    totalUsers: 0,
    newUsers: 0,
    activeUsers: 0,
    inactiveUsers: 0,
    enrolledStudents: 0,
    incomingFreshmen: 0,
    userAffiliations: {},
    scholarshipDistribution: {},
    usersWithScholarship: 0,
    usersWithoutScholarship: 0,
    userGrowthOverTime: [],
    usersByYear: {},
    usersByProgram: {},
        enrolledRatio: '',
    activeUserRatio: '',
  );
}