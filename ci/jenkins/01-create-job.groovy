import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*
import hudson.triggers.SCMTrigger

def jobName = "damolak-api-pipeline"
def j = Jenkins.instance

if (j.getItem(jobName) == null) {
    WorkflowJob job = j.createProject(WorkflowJob.class, jobName)
    def gitRepo = "https://github.com/Legacy-G/ecs-pc-platform.git"
    def scm = new GitSCM(gitRepo)
    scm.branches = [new BranchSpec("*/main")]
    job.definition = new CpsScmFlowDefinition(scm, "Jenkinsfile")
    job.addTrigger(new SCMTrigger("H/2 * * * *"))
    job.save()
    println "Created Pipeline job: ${jobName}"
}
