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

type FaqSeed = {
  id: string;
  question: string;
  answer: string;
  category: "Admission" | "Scholarship" | "Placement";
};

// Replace these examples with the FAQs for your application.
const faqSeeds: FaqSeed[] = [
  {
    id: "admission-how-to-apply",
    question: "How do I apply for admission?",
    answer:
      "Submit the online application form and provide all required supporting documents before the application deadline.",
    category: "Admission",
  },
  {
    id: "admission-required-documents",
    question: "What documents are required for admission?",
    answer:
      "The required documents depend on the programme. Check the programme information and upload the documents listed in the application form.",
    category: "Admission",
  },
  {
    id: "admission-application-deadline",
    question: "When is the admission application deadline?",
    answer:
      "Application deadlines vary by programme and intake. Check the programme information for the applicable deadline before submitting your application.",
    category: "Admission",
  },
  {
    id: "admission-check-application-status",
    question: "How can I check my admission application status?",
    answer:
      "Sign in to the application portal and open your application to view its latest status and any outstanding requirements.",
    category: "Admission",
  },
  {
    id: "admission-application-review",
    question: "How long does the admission application review take?",
    answer:
      "Review times vary by programme and intake. You can monitor your application status in the application portal while it is being reviewed.",
    category: "Admission",
  },
  {
    id: "scholarship-available",
    question: "What scholarships are available?",
    answer:
      "Available scholarships and their eligibility requirements are listed in the Scholarships section of the application portal.",
    category: "Scholarship",
  },
  {
    id: "scholarship-eligibility",
    question: "Who is eligible to apply for a scholarship?",
    answer:
      "Eligibility depends on the scholarship. Review its academic, financial, citizenship, and programme requirements before applying.",
    category: "Scholarship",
  },
  {
    id: "scholarship-application-process",
    question: "How do I apply for a scholarship?",
    answer:
      "Complete the scholarship application form and submit the required supporting documents before the scholarship deadline.",
    category: "Scholarship",
  },
  {
    id: "scholarship-application-deadline",
    question: "When is the scholarship application deadline?",
    answer:
      "Scholarship deadlines differ by award and intake. Check the scholarship details for the correct submission deadline.",
    category: "Scholarship",
  },
  {
    id: "scholarship-renewal",
    question: "Can I renew my scholarship for the next academic year?",
    answer:
      "Renewal depends on the scholarship conditions and your academic performance. Check the award terms for renewal requirements.",
    category: "Scholarship",
  },
  {
    id: "placement-support",
    question: "What placement support is available to students?",
    answer:
      "Placement support may include career guidance, employer events, internship opportunities, and assistance with preparing applications.",
    category: "Placement",
  },
  {
    id: "placement-internship",
    question: "How do I apply for an internship placement?",
    answer:
      "Check the available placement opportunities, prepare the requested documents, and submit your application according to the instructions provided.",
    category: "Placement",
  },
  {
    id: "placement-eligibility",
    question: "Who is eligible for placement opportunities?",
    answer:
      "Eligibility varies by opportunity. Review the placement requirements for the programme, academic standing, skills, and application period.",
    category: "Placement",
  },
  {
    id: "placement-career-services",
    question: "Where can I get help with my placement application?",
    answer:
      "Contact the career or placement support team for guidance on preparing your resume, submitting applications, and preparing for interviews.",
    category: "Placement",
  },
  {
    id: "placement-required-documents",
    question: "What documents do I need for a placement application?",
    answer:
      "Most placement applications require a resume and may require a cover letter, academic records, or other documents specified by the employer.",
    category: "Placement",
  },
];

function normalizeFaqQuestion(text: string): string {
  return text
    .trim()
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function seedFaqs(): Promise<void> {
  const db = admin.firestore();
  const batch = db.batch();

  for (const faq of faqSeeds) {
    const faqRef = db.collection("faqs").doc(faq.id);

    batch.set(
      faqRef,
      {
        question: faq.question,
        questionNormalized: normalizeFaqQuestion(faq.question),
        answer: faq.answer,
        category: faq.category,
        isPredefined: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        similarityCount: 0,
        // The chatbot will generate and cache the embedding when needed.
        embedding: [],
      },
      {merge: true},
    );
  }

  await batch.commit();
  console.log(`Seeded ${faqSeeds.length} FAQs into the "faqs" collection.`);
}

seedFaqs().catch((error: unknown) => {
  console.error("Failed to seed FAQs:", error);
  process.exitCode = 1;
});
