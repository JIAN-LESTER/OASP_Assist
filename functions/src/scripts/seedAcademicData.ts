import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp({
    // Standalone scripts do not receive the project ID from the Firebase CLI.
    projectId:
      process.env.GCLOUD_PROJECT ||
      process.env.GCP_PROJECT ||
      "cmu-oasp-assist",
  });
}

type CollegeSeed = {
  id: string;
  name: string;
};

type BachelorProgramSeed = {
  id: string;
  name: string;
  collegeId: string;
};

type MasteralProgramSeed = {
  id: string;
  name: string;
};

const collegeSeeds: CollegeSeed[] = [
  {id: "college-agriculture", name: "College of Agriculture"},
  {id: "college-arts-sciences", name: "College of Arts and Sciences"},
  {id: "college-business-management", name: "College of Business and Management"},
  {id: "college-education", name: "College of Education"},
  {id: "college-engineering", name: "College of Engineering"},
  {
    id: "college-forestry-environmental-science",
    name: "College of Forestry and Environmental Science",
  },
  {id: "college-human-ecology", name: "College of Human Ecology"},
  {
    id: "college-information-sciences-computing",
    name: "College of Information Sciences and Computing",
  },
  {id: "college-nursing", name: "College of Nursing"},
  {
    id: "college-veterinary-medicine",
    name: "College of Veterinary Medicine",
  },
];

const bachelorProgramSeeds: BachelorProgramSeed[] = [
  {
    id: "bachelor-agriculture",
    name: "Bachelor of Science in Agriculture",
    collegeId: "college-agriculture",
  },
  {
    id: "bachelor-agribusiness-management",
    name: "Bachelor of Science in Agribusiness Management",
    collegeId: "college-agriculture",
  },
  {
    id: "bachelor-biology",
    name: "Bachelor of Science in Biology",
    collegeId: "college-arts-sciences",
  },
  {
    id: "bachelor-psychology",
    name: "Bachelor of Science in Psychology",
    collegeId: "college-arts-sciences",
  },
  {
    id: "bachelor-accountancy",
    name: "Bachelor of Science in Accountancy",
    collegeId: "college-business-management",
  },
  {
    id: "bachelor-business-administration",
    name: "Bachelor of Science in Business Administration",
    collegeId: "college-business-management",
  },
  {
    id: "bachelor-elementary-education",
    name: "Bachelor of Elementary Education",
    collegeId: "college-education",
  },
  {
    id: "bachelor-secondary-education",
    name: "Bachelor of Secondary Education",
    collegeId: "college-education",
  },
  {
    id: "bachelor-agricultural-biosystems-engineering",
    name: "Bachelor of Science in Agricultural and Biosystems Engineering",
    collegeId: "college-engineering",
  },
  {
    id: "bachelor-civil-engineering",
    name: "Bachelor of Science in Civil Engineering",
    collegeId: "college-engineering",
  },
  {
    id: "bachelor-forestry",
    name: "Bachelor of Science in Forestry",
    collegeId: "college-forestry-environmental-science",
  },
  {
    id: "bachelor-environmental-science",
    name: "Bachelor of Science in Environmental Science",
    collegeId: "college-forestry-environmental-science",
  },
  {
    id: "bachelor-nutrition-dietetics",
    name: "Bachelor of Science in Nutrition and Dietetics",
    collegeId: "college-human-ecology",
  },
  {
    id: "bachelor-food-technology",
    name: "Bachelor of Science in Food Technology",
    collegeId: "college-human-ecology",
  },
  {
    id: "bachelor-information-technology",
    name: "Bachelor of Science in Information Technology",
    collegeId: "college-information-sciences-computing",
  },
  {
    id: "bachelor-computer-science",
    name: "Bachelor of Science in Computer Science",
    collegeId: "college-information-sciences-computing",
  },
  {
    id: "bachelor-nursing",
    name: "Bachelor of Science in Nursing",
    collegeId: "college-nursing",
  },
  {
    id: "bachelor-development-communication",
    name: "Bachelor of Science in Development Communication",
    collegeId: "college-arts-sciences",
  },
  {
    id: "doctor-veterinary-medicine",
    name: "Doctor of Veterinary Medicine",
    collegeId: "college-veterinary-medicine",
  },
  {
    id: "bachelor-hospitality-management",
    name: "Bachelor of Science in Hospitality Management",
    collegeId: "college-business-management",
  },
];

const masteralProgramSeeds: MasteralProgramSeed[] = [
  {id: "master-agronomy", name: "Master of Science in Agronomy"},
  {id: "master-animal-science", name: "Master of Science in Animal Science"},
  {id: "master-biology", name: "Master of Science in Biology"},
  {id: "master-mathematics", name: "Master of Science in Mathematics"},
  {id: "master-chemistry", name: "Master of Science in Chemistry"},
  {id: "master-business-administration", name: "Master of Business Administration"},
  {id: "master-public-administration", name: "Master of Public Administration"},
  {id: "master-education", name: "Master of Arts in Education"},
  {id: "master-educational-management", name: "Master of Arts in Educational Management"},
  {id: "master-english-language-studies", name: "Master of Arts in English Language Studies"},
  {id: "master-agricultural-engineering", name: "Master of Science in Agricultural Engineering"},
  {id: "master-civil-engineering", name: "Master of Science in Civil Engineering"},
  {id: "master-forestry", name: "Master of Science in Forestry"},
  {id: "master-environmental-science", name: "Master of Science in Environmental Science"},
  {id: "master-food-science", name: "Master of Science in Food Science"},
  {id: "master-nutrition", name: "Master of Science in Nutrition"},
  {id: "master-information-technology", name: "Master of Information Technology"},
  {id: "master-computer-science", name: "Master of Science in Computer Science"},
  {id: "master-nursing", name: "Master of Science in Nursing"},
  {id: "master-veterinary-medicine", name: "Master of Science in Veterinary Medicine"},
];

async function seedAcademicData(): Promise<void> {
  const db = admin.firestore();
  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const college of collegeSeeds) {
    batch.set(
      db.collection("colleges").doc(college.id),
      {
        name: college.name,
        createdAt: now,
        updatedAt: now,
      },
      {merge: true},
    );
  }

  for (const program of bachelorProgramSeeds) {
    batch.set(
      db.collection("programs").doc(program.id),
      {
        name: program.name,
        category: "Bachelor",
        collegeId: program.collegeId,
        created_at: now,
        updatedAt: now,
      },
      {merge: true},
    );
  }

  for (const program of masteralProgramSeeds) {
    batch.set(
      db.collection("programs").doc(program.id),
      {
        name: program.name,
        category: "Masteral",
        collegeId: "",
        created_at: now,
        updatedAt: now,
      },
      {merge: true},
    );
  }

  await batch.commit();
  console.log(
    "Academic seed completed successfully: " +
      `${collegeSeeds.length} colleges, ` +
      `${bachelorProgramSeeds.length} bachelor programs, and ` +
      `${masteralProgramSeeds.length} masteral programs were written.`,
  );
}

seedAcademicData().catch((error: unknown) => {
  console.error("Failed to seed academic data:", error);
  process.exitCode = 1;
});
