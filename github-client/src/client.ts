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

  console.log(repo_path.repository.url);
  const info = repo_path.repository.url.match(/https:\/\/github.com\/(.*?)\/(.*)/);
  
  const repo = await octokit.request("GET /repos/{owner}/{repo}", {
    owner: info![1],
    repo: (info![2].replace('.git', '')).split('/')[0]
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

export const getDependencies = async (id: number, etag: string):Promise<DependencyInfo> => {
  const packages_file = await get_packages_file(id);
  if (packages_file.headers.etag === etag) {
    return { 'updated': false, 'ids': [], 'etag': etag}
  }

  // package.json has been updated
  // fetch new dependency list
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
    updated: true,
    ids:
      (await get_repo_ids(dependencies)).concat(await get_repo_ids(devDependencies)),
    etag: packages_file.headers.etag!,
  };
};

//getDependencies(511402884, 'W/"15c736237d5e3d5d10a382e8f31eddd6a80f396a"').then((res) => console.log(res));