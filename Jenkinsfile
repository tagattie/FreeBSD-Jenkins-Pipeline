#! /usr/bin/env groovy

pipeline {
    agent any
    environment {
        // Configuration file (JSON)
        CONFIG='Config.json'
        // Build name based on current date/time
        BUILDNAME=sh (
            returnStdout: true,
            script: 'date "+%Y-%m-%d-%H%M%S"'
        ).trim()
    }
    // parameters {
    // }
    // triggers {
    // }
    stages {
        stage('Checkout Jenkinsfile and other files.') {
            steps {
                timestamps {
                    checkout scm
                    archiveArtifacts 'Jenkinsfile'
                    archiveArtifacts '*.sh'
                    archiveArtifacts 'Config.json'
                }
            }
        }

        stage('Read config file and do some preparations.') {
            steps {
                timestamps {
                    script {
                        config = readJSON(file: "${CONFIG}")
                        changed = config.freebsd.branches.collectEntries(
                            {
                                [it, 0]
                            }
                        )
                        echo "changed (initial) = ${changed}"
                        buildable = config.freebsd.branches.collectEntries(
                            {
                                [it, true]
                            }
                        )
                        echo "buildable (initial) = ${buildable}"
                        pollSteps = config.freebsd.branches.collectEntries(
                            {
                                [it, transformIntoPollStep(it)]
                            }
                        )
                        updateSteps = config.freebsd.branches.collectEntries(
                            {
                                [it, transformIntoUpdateStep(it)]
                            }
                        )

                        def buildMap = config.freebsd.build
                        def buildPairs = distributeMapToPairs(buildMap)
                        buildSteps = buildPairs.collectEntries(
                            {
                                [it, transformIntoBuildStep(it[0], it[1])]
                            }
                        )
                        buildHostSteps = config.freebsd.hosts.collectEntries(
                            {
                                [it.getValue().get('hostname'), transformIntoBuildHostStep(it.getValue().get('hostname'))]
                            }
                        )
                        currentBuild.description += ' SUCCESS(config)'
                    }
                }
            }
            post {
                failure {
                    timestamps {
                        script {
                            currentBuild.description += ' FAILURE(config)'
                        }
                    }
                }
            }
        }

        stage('Poll SCM.') {
            when {
                environment name: 'doPoll', value: 'true'
            }
            steps {
                script {
                    parallel(pollSteps)
                }
            }
            post {
                always {
                    echo "changed = ${changed}"
                }
            }
        }

        stage('Update source tree.') {
            when {
                environment name: 'doUpdate', value: 'true'
            }
            steps {
                script {
                    parallel(updateSteps)
                }
            }
            post {
                always {
                    echo "buildable = ${buildable}"
                }
            }
        }

        stage('Build world and generic kernel.') {
            when {
                environment name: 'doBuild', value: 'true'
            }
            steps {
                script {
                    parallel(buildSteps)
                }
            }
        }

        stage('Build host.') {
            when {
                environment name: 'doBuildHost', value: 'true'
            }
            steps {
                script {
                    parallel(buildHostSteps)
                }
            }
        }
    }

    post {
        always {
            timestamps {
                echo "${changed}"
                echo "${buildable}"
            }
        }
    }
}

def transformIntoPollStep(String inputStr) {
    return {
        timestamps {
            try {
                changed[inputStr] = sh (
                    returnStdout: true,
                    script: "svnlite status -qu ${config.freebsd.srcDirs."${inputStr}"} | wc -l").trim() as Integer
                currentBuild.description += " SUCCESS(poll ${inputStr} ${changed["${inputStr}"]})"
            } catch (Exception e) {
                currentBuild.description += " FAILURE(poll ${inputStr})"
                throw e
            }
        }
    }
}

def transformIntoUpdateStep(String inputStr) {
    return {
        timestamps {
            if (changed[inputStr] > 0) {
                try {
                    sh "sudo svnlite update ${config.freebsd.srcDirs."${inputStr}"}"
                    currentBuild.description += " SUCCESS(update ${inputStr})"
                } catch (Exception e) {
                    buildable[inputStr] = false
                    currentBuild.description += " FAILURE(update ${inputStr})"
                    throw e
                }
            }
        }
    }
}

def transformIntoBuildStep(String branchStr, String archStr) {
    return {
        timestamps {
            if ((changed[branchStr] > 0 && buildable[branchStr]) ||
                "${forceBuild}" == "true") {
                try {
                    sh """
${WORKSPACE}/Build.sh \\
    ${config.freebsd.srcDirs."${branchStr}"} \\
    ${config.freebsd.objDirBase}/"${BUILDNAME}"/"${branchStr}" \\
    ${config.freebsd.archs."${archStr}".arch_m} \\
    ${config.freebsd.archs."${archStr}".arch_p} \\
    "" \\
    "" \\
    "" \\
    buildworld \\
    buildkernel
"""
                    currentBuild.description += " SUCCESS(build buildworld & buildkernel:${branchStr}:${archStr})"
                } catch (Exception e) {
                    currentBuild.description += " FAILURE(build buildworld & buildkernel:${branchStr}:${archStr})"
                    throw e
                }
            }
        }
    }
}

def transformIntoBuildHostStep(String hostStr) {
    return {
        timestamps {
            if ((changed["${config.freebsd.hosts."${hostStr}".branch}"] > 0 &&
                 buildable["${config.freebsd.hosts."${hostStr}".branch}"]) ||
                "${forceBuild}" == "true") {
                try {
                    def targets = ""
                    config.freebsd.hosts."${hostStr}".steps.each {
                        targets += "${it}" + " "
                    }
                    sh """
${WORKSPACE}/Build.sh \\
    ${config.freebsd.srcDirs."${config.freebsd.hosts."${hostStr}".branch}"} \\
    ${config.freebsd.objDirBase}/"{BUILDNAME}"/"${hostStr}" \\
    ${config.freebsd.archs."${config.freebsd.hosts."${hostStr}".arch}".arch_m} \\
    ${config.freebsd.archs."${config.freebsd.hosts."${hostStr}".arch}".arch_p} \\
    ${config.freebsd.hosts."${hostStr}".kernConf} \\
    ${config.freebsd.destDirBase}/"{BUILDNAME}"/"${hostStr}" \\
    ${config.freebsd.hosts."${hostStr}".addMakeEnv} \\
    ${targets}
"""
                    currentBuild.description += " SUCCESS(build ${hostStr})"
                } catch (Exception e) {
                    currentBuild.description += " FAILURE(build ${hostStr})"
                    throw e
                }
            }
        }
    }
}


def distributeMapToPairs(Map buildMap) {
    def pairs = []
    buildMap.each {
        if (it.getValue().get('enabled') == true) {
            def branch = it.getValue().get('branch')
            def archs = it.getValue().get('archs')
            archs.each {
                def pair = [branch, it]
                pairs.push(pair)
            }
        }
    }
    return pairs
}
