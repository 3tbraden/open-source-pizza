import { DependencyInfo, NpmRegistryResponse, packageObject } from "./type";
import axios from "axios";
import { Octokit } from "@octokit/rest";
import { GetResponseDataTypeFromEndpointMethod, OctokitResponse } from "@octokit/types"


const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN,
});

type ContentResponse = Promise<OctokitResponse<GetResponseDataTypeFromEndpointMethod<typeof octokit.repos.getContent>, 200>>
const get_repo_id_by_package_name = async (name: string): Promise<number> => {
  const repo_path = await axios.get(`https://registry.npmjs.org/${name}`).then(
    (res) => res.data
  ) as NpmRegistryResponse;

  const info = repo_path.repository.url.match(/.*\/\/.*\/(.*)\/(.*)/);
  const repo = await octokit.request("GET /repos/{owner}/{repo}", {
    owner: info![1],
    repo: info![2]
  });

  return repo.data.id;
};

const get_repo_ids = async (dependencies: object) => {
  const ids: number[] = [];
  
  for (const dependency in dependencies) {
    ids.push(await get_repo_id_by_package_name(dependency));
  }

  return ids;
};

const get_packages_file = async (id: number): Promise<ContentResponse> => {
  const repo = await octokit.request("GET /repositories/{id}", {
    id: id,
  });

  return await octokit.request("GET /repos/{owner}/{repo}/contents/{path}", {
    owner: repo.data.owner.login,
    repo: repo.data.name,
    path: "package.json",
  });
};

export const getDependencies = async (id: number) => {
  const packages_file = await get_packages_file(id);
  const data = packages_file.data;
  type keys = keyof typeof data;
  const package_obj = await axios.get(data['download_url' as keys], {
    method: "GET",
  }).then((res) => res.data) as packageObject;
  const dependencies = package_obj.dependencies ? package_obj.dependencies : {};
  const devDependencies = package_obj.devDependencies
    ? package_obj.devDependencies
    : {};
  return {
    id: id,
    ids:
      (await get_repo_ids(dependencies)).concat(await get_repo_ids(devDependencies)),
    etag: packages_file.headers.etag,
  };
};

export const isSync = async (dependencies: DependencyInfo) => {
  const packages_file = await get_packages_file(dependencies.project_id);
  return packages_file.headers.etag == dependencies.etag;
};


// const test:DependencyInfo = {
//   project_id: 511402884,
//   ids: [128778692,125863507,149638165,10270250,10270250,63537249,31434220,249512698],
//   etag: 'W/"3089b46c3ea95ef00a26510bb1c09917522b1617"',
// };


//getDependencies(511402884).then((res) => console.log(res));
//isSync(test).then((res) => console.log(res));
